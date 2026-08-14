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

    @Guide(
        description:
            "An optional task-specific hint that tells the captioning model what to focus on when describing the sketch. Use this argument when the user’s request requires attention to particular visual details, objects, regions, layers, or relationships."
    )
    let hint: String
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
    nonisolated static let NAME = "caption_sketch"
    let name = Self.NAME
    let description = """
        Use this tool when you need to understand what the user has currently drawn in their sketch.

        It analyzes the visible sketch and returns a detailed description of its visual content. Use this description to reason about the drawing, answer questions about what is shown, or perform tasks that require understanding the sketch.

        Base your reasoning only on information that is visually present and reliably discernible based on the output of this caption tool. Do not assume, infer, or invent details that cannot be determined from the drawing.
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

        let image = try sketch.render.renderLayers(indices: indices)
        guard let imageData = image.pngData() else {
            throw CaptionToolError.imageRenderFailed
        }

        var description = ""
        let stream = visualModel.generate(
            prompt:
                """
                Here is the current state of the sketch:

                \(sketch.description)

                Describe what the user appears to be trying to sketch based only on the visual content. Identify the most likely recognizable subject, object, symbol, or scene (for example, a plane, house, tree, person, or car) when the sketch provides enough visual evidence to support that interpretation.

                Start with the most likely intended subject in plain language, then briefly describe the visual evidence supporting it. If the sketch is ambiguous, incomplete, abstract, or too rough to identify confidently, say what it most resembles and indicate the uncertainty rather than inventing details.

                Focus on what the user appears to be drawing rather than merely listing individual strokes or geometric primitives.

                Do not infer details that are not visually supported by the sketch. Distinguish clearly between confident identification and uncertain interpretation.
                Captioning hint:
                \(arguments.hint)

                Use this hint to prioritize relevant visual features and tailor the description to the user's task.
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
