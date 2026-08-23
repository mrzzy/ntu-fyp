//
//  RenderTool.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-28
//

import Foundation
import FoundationModels
import UIKit

enum RenderToolError: Error, LocalizedError {
    case notEnoughLayers(layerCount: Int)
    case imageRenderFailed
    case imageEditFailed

    var errorDescription: String? {
        switch self {
        case .notEnoughLayers(let count):
            return
                "Not enough layers to render. Need at least 1 layer, got \(count)."
        case .imageRenderFailed:
            return "Failed to render sketch layers into an image."
        case .imageEditFailed:
            return "Failed to edit the rendered sketch image."
        }
    }
}

@Generable
struct RenderArguments: Codable, Sendable {
    @Guide(
        description:
            """
            A text prompt describing only the desired rendering style to apply to the sketch. \
            Focus on visual style, artistic medium, rendering technique, lighting, color palette, \
            A text prompt describing the desired rendering style, medium, or edits to apply to the sketch image.
            If the generated image is likely contain visible text, transcribe the exact text verbatim in quotation marks, e.g. "Hello World".
            """
    )
    let prompt: String
}

@Generable
struct RenderOutput: Codable, Sendable {
    @Guide(
        description:
            "Confirmation that the sketch layers have been rendered into an image layer appended to the sketch."
    )
    let message: String
}

struct RenderTool: AITool {
    nonisolated static let NAME = "render_sketch"
    let name = Self.NAME
    let description =
        """
        Generate a polished image from the user's sketch using AI image generation. 
        Use this tool when the user wants their sketch rendered into a finished or more polished image.
        """
    let repo: Repository = .shared

    let sketch: Sketch
    let imageModel: ImageAIModel

    func call(arguments: RenderArguments) async throws -> RenderOutput {
        let layers = sketch.layers
        guard !layers.isEmpty else {
            throw RenderToolError.notEnoughLayers(layerCount: 0)
        }

        let indices = 0..<layers.count

        let image = try sketch.render.renderLayers(indices: indices)
        guard let imageData = image.pngData() else {
            throw RenderToolError.imageRenderFailed
        }

        // render the image using the image generation model
        var resultImageData: Data?
        let stream = imageModel.edit(
            images: [imageData],
            prompt:
                """
                Current Sketch description:
                \(sketch.description)

                Create a polished image based on the user's sketch and the provided rendering prompt.
                Preserve the important subject, composition, spatial relationships, and overall intent of the sketch while transforming it into a coherent, refined image.
                Generate only the subject content depicted by the sketch.
                Use the stylistic and rendering instructions provided in the prompt to guide the transformation.
                Do not add unrelated objects or alter the core composition.
                Do not add text unless explicit quoted below in the rendering prompt.

                Rendering prompt:
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
            throw RenderToolError.imageEditFailed
        }

        // append the rendered image as a new layer in the sketch
        sketch.addLayer(.image(data: resultImageData))
        // append a sketchable layer on top of the rendered image layer for further sketching
        sketch.addLayer(.drawing())
        // save changes
        repo.save()

        return RenderOutput(
            message: "Rendered layers \(indices) into a new image layer appended to the sketch."
        )
    }
}
