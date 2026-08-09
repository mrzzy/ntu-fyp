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
            A text prompt describing the desired rendering style, medium, or edits to apply to the sketch image.
            You should use the '\(CaptionTool.NAME)' tool to describe what the user has already sketched in generating the prompt.
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
    static let NAME = "render_sketch"
    let name = NAME
    let description =
        """
        Render the specified sketch layers into a polished final image using AI image generation.

        Use this tool when the user wants to transform their sketch into a generated image. Before calling this tool, call `\(CaptionTool.NAME)` to analyze the sketch and describe its visual content. Use the resulting description to create an appropriate rendering prompt.

        Do not call this tool without first analyzing the sketch with `\(CaptionTool.NAME)`.
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

        let image = try sketch.renderLayers(indices: indices)
        guard let imageData = image.pngData() else {
            throw RenderToolError.imageRenderFailed
        }

        var resultImageData: Data?
        let stream = imageModel.edit(
            image: imageData,
            prompt:
                """
                Current Sketch description:
                \(sketch.description)

                Create a polished image based on the user's sketch and the provided rendering prompt.
                Preserve the important elements, composition, spatial relationships, and overall intent of the sketch while transforming it into a coherent, refined image.
                Generate only the image content described by the rendering prompt. Do not add unrelated objects or alter the core composition unless necessary to produce a coherent result.

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

        sketch.layers.append(.image(data: resultImageData))

        return RenderOutput(
            message: "Rendered layers \(indices) into a new image layer appended to the sketch."
        )
    }
}
