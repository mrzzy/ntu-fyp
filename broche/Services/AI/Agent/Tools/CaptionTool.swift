//
//  CaptionTool.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-28
//

import Foundation
import FoundationModels
import UIKit

enum CaptionToolError: Error, LocalizedError {
    case invalidLayerIndices(start: Int, end: Int, layerCount: Int)
    case imageRenderFailed

    var errorDescription: String? {
        switch self {
        case .invalidLayerIndices(let start, let end, let layerCount):
            return
                "Invalid layer indices: range \(start)..<\(end) is out of bounds for \(layerCount) layers."
        case .imageRenderFailed:
            return "Failed to render sketch layers into an image for captioning."
        }
    }
}

@Generable
struct CaptionArguments: Codable, Sendable {
    @Guide(
        description:
            "Start index (inclusive) of the layer range to caption. Omit to caption all layers."
    )
    let layerStart: Int?

    @Guide(
        description:
            "End index (exclusive) of the layer range to caption. Omit to caption all layers."
    )
    let layerEnd: Int?
}

@Generable
struct CaptionOutput: Codable, Sendable {
    @Guide(
        description: "A text description of what is drawn in the specified layers of the sketch."
    )
    let description: String
}

/// A tool that generates a caption for a sketch or a specified range of layers within the sketch.
struct CaptionTool: AITool {
    static let NAME = "caption_sketch"
    let name = NAME
    let description = """
        Describe the user's sketch in detail, including the subjects, composition, spatial relationships, and key visual elements. Use this tool to understand the sketch before generating an image.
        """

    let sketch: Sketch
    let visualModel: VisualAIModel

    /// Initializes the CaptionTool with a sketch and a visual AI model.
    init(sketch: Sketch, visualModel: VisualAIModel) {
        self.sketch = sketch
        self.visualModel = visualModel
    }

    func call(arguments: CaptionArguments) async throws -> CaptionOutput {
        let indices: Range<Int>
        if let start = arguments.layerStart, let end = arguments.layerEnd {
            let range = start..<end
            guard range.lowerBound >= 0, range.upperBound <= sketch.layers.count,
                !range.isEmpty
            else {
                throw CaptionToolError.invalidLayerIndices(
                    start: start, end: end, layerCount: sketch.layers.count
                )
            }
            indices = range
        } else {
            indices = 0..<sketch.layers.count
        }

        let image = try sketch.renderLayers(indices: indices)
        guard let imageData = image.pngData() else {
            throw CaptionToolError.imageRenderFailed
        }

        var description = ""
        let stream = visualModel.generate(
            prompt:
                """
                Here is the current state of the sketch:

                \(sketch.description)

                Describe the sketch image in detail based only on what is visually present. Identify the main subjects, objects, shapes, colors, positions, relative sizes, spatial relationships, composition, and any other notable visual details.

                Be precise and concrete. Preserve important visual relationships and distinguish clearly between elements that are visible and details that are uncertain or ambiguous. Do not infer information that cannot be supported by the image.
                """,
            images: [imageData],
            options: VisualAIOptions()
        )
        for try await output in stream {
            switch output {
            case .chunk(let text):
                description += text
            case .call(let call):
                print("Ignoring Unexpected tool call during caption generation: \(call)")
            case .complete:
                break
            }
        }

        return CaptionOutput(description: description)
    }
}
