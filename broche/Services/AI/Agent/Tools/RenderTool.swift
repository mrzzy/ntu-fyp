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
    case invalidLayerIndices(start: Int, end: Int, layerCount: Int)
    case imageRenderFailed
    case imageEditFailed

    var errorDescription: String? {
        switch self {
        case .invalidLayerIndices(let start, let end, let layerCount):
            return
                "Invalid layer indices: range \(start)..<\(end) is out of bounds for \(layerCount) layers."
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
            "Start index (inclusive) of the layer range to render. Omit to render all layers."
    )
    let layerStart: Int?

    @Guide(
        description:
            "End index (exclusive) of the layer range to render. Omit to render all layers."
    )
    let layerEnd: Int?

    @Guide(
        description:
            """
            A comprehensive text prompt describing the desired rendering composition, style, medium, or edits to apply to the sketch image.
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
        Generate a polished image from the user's sketch using AI image generation. Use this tool when the user wants their sketch turned into a finished or more polished image.
        """

    let sketch: Sketch
    let imageModel: ImageAIModel

    func call(arguments: RenderArguments) async throws -> RenderOutput {
        let indices: Range<Int>
        if let start = arguments.layerStart, let end = arguments.layerEnd {
            let range = start..<end
            guard range.lowerBound >= 0, range.upperBound <= sketch.layers.count,
                !range.isEmpty
            else {
                throw RenderToolError.invalidLayerIndices(
                    start: start, end: end, layerCount: sketch.layers.count
                )
            }
            indices = range
        } else {
            indices = 0..<sketch.layers.count
        }

        let image = try sketch.render.renderLayers(indices: indices)
        guard let imageData = image.pngData() else {
            throw RenderToolError.imageRenderFailed
        }

        // render the image using the image generation model
        var resultImageData: Data?
        let stream = imageModel.edit(
            image: imageData,
            prompt:
                """
                Current Sketch description:
                \(sketch.description)

                Create a polished image based on the user's sketch and the provided rendering prompt.
                Preserve the important elements, composition, spatial relationships, and overall intent of the sketch while transforming it into a coherent, refined image.
                Generate only the image content described by the rendering prompt. Do not add unrelated objects or text or alter the core composition unless necessary to produce a coherent result.

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

        return RenderOutput(
            message: "Rendered layers \(indices) into a new image layer appended to the sketch."
        )
    }
}
