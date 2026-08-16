//
//  EditTool.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-08-13.
//

import Foundation
import FoundationModels
import UIKit

enum EditToolError: Error, LocalizedError {
    case notEnoughLayers(layerCount: Int)
    case imageRenderFailed
    case imageEditFailed

    var errorDescription: String? {
        switch self {
        case .notEnoughLayers(let count):
            return
                "Not enough layers to edit. Need at least 2 layers, got \(count)."
        case .imageRenderFailed:
            return "Failed to render sketch layers into images."
        case .imageEditFailed:
            return "Failed to edit the rendered sketch image."
        }
    }
}

@Generable
struct EditArguments: Codable, Sendable {
    @Guide(
        description:
            """
            A prompt describing the desired edit to apply to image 1. \
            Be specific about what to add, remove, or change, and describe how \
            image 2's edits should be applied to image 1. 
            Include the placement, materials, objects, and visual \
            style needed to achieve the edit. 
            If the generated image is likely contain visible text, transcribe the exact text verbatim in quotation marks, e.g. "Hello World".
            """
    )
    let prompt: String
}

@Generable
struct EditOutput: Codable, Sendable {
    @Guide(
        description:
            "Confirmation that the top layer has been edited using the AI image model."
    )
    let message: String
}

struct EditTool: AITool {
    nonisolated static let NAME = "edit_sketch"
    let name = Self.NAME
    let description =
        """
        Apply an incremental edit to the sketch. \
        The image 1 is the previous sketch, image 2 is the new edit layer drawn by the user.
        Use this tool when the user wants to add, remove, correct, or refine something
        in the existing sketch. Treat the 2 image as a change to apply to the first.
        """
    let repo: Repository = .shared

    let sketch: Sketch
    let imageModel: ImageAIModel

    func call(arguments: EditArguments) async throws -> EditOutput {
        let layers = sketch.layers
        guard layers.count >= 2 else {
            throw EditToolError.notEnoughLayers(layerCount: layers.count)
        }

        let backgroundImage = try sketch.render.renderLayers(indices: 0..<(layers.count - 1))
        guard let backgroundImageData = backgroundImage.pngData() else {
            throw EditToolError.imageRenderFailed
        }

        let foregroundLayer = layers[layers.count - 1]
        let foregroundImageData = try foregroundLayer.render(size: sketch.size)

        var resultImageData: Data?
        let stream = imageModel.edit(
            images: [backgroundImageData, foregroundImageData],
            prompt:
                """
                You are editing the sketch using the provided images:

                - Image 1: the existing sketch context, showing all layers below the top layer.
                - Image 2: the current top layer which depicts the changes drawn out by the user.
                - Images 3 and onward: additional reference images provided in the edit request. Use them only as references for the specific materials, objects, or details requested.

                Apply the requested edit in Image 2 to Image 1 as an incremental change, while style consistent with Image 1.

                Preserve elements from Image 1 that are not part of the requested edit. 
                Do not add unrelated objects or alter the core composition.
                Do not add text unless explicit quoted below in the rendering prompt.

                \(arguments.prompt)
                """,
            options: ImageAIOptions()
        )
        for try await output in stream {
            switch output {
            case .progress:
                break
            case .image(let data, _):
                resultImageData = data
            }
        }
        guard let resultImageData else {
            throw EditToolError.imageEditFailed
        }

        sketch.addLayer(.image(data: resultImageData))
        sketch.addLayer(.drawing())
        // save changes
        repo.save()

        return EditOutput(
            message:
                "Edited the top layer and appended a new drawing layer on top."
        )
    }
}
