//
//  ExplainEditTool.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-08-14.
//

import Foundation
import FoundationModels
import UIKit

enum ExplainEditToolError: Error, LocalizedError {
    case notEnoughLayers(layerCount: Int)
    case imageRenderFailed

    var errorDescription: String? {
        switch self {
        case let .notEnoughLayers(count):
            return
                "Not enough layers to explain edit. Need at least 2 layers, got \(count)."
        case .imageRenderFailed:
            return "Failed to render sketch layers into images."
        }
    }
}

@Generable
struct ExplainEditArguments: Codable, Sendable {
    @Guide(
        description:
        "An optional hint that tells the description model what to focus on when analyzing the edit. Use this when the user's request requires attention to particular aspects of the change, such as spatial relationships, material changes, or specific regions."
    )
    let hint: String
}

@Generable
struct ExplainEditOutput: Codable, Sendable {
    @Guide(
        description:
        "A text description of the edit drawn on the top layer relative to the background layers."
    )
    let description: String
}

struct ExplainEditTool: AITool {
    nonisolated static let NAME = "explain_edit"
    let name = Self.NAME
    let description =
        """
        Explains an edit drawn over an existing sketch.

        Use this tool when the user wants to change something specific in the sketch. Treat
        Image 1 as the existing sketch and Image 2 as the user's proposed edit or instruction.
        Compare both images to determine what the user wants to change.

        For any inference about the user's intent, briefly explain the visual evidence supporting
        it. If the intended edit is ambiguous, state the uncertainty rather than guessing.

        Do not use it for general sketch descriptions. Base the interpretation only on what is
        visibly supported by the two images.
        """

    let sketch: Sketch
    let visualModel: VisualAIModel

    func call(arguments: ExplainEditArguments) async throws -> ExplainEditOutput {
        let layers = sketch.layers
        guard layers.count >= 2 else {
            throw ExplainEditToolError.notEnoughLayers(layerCount: layers.count)
        }

        let backgroundImage = try sketch.render.renderLayers(
            indices: 0 ..< (layers.count - 1)
        )
        guard let backgroundImageData = backgroundImage.pngData() else {
            throw ExplainEditToolError.imageRenderFailed
        }

        let foregroundLayer = layers[layers.count - 1]
        let foregroundImageData = try foregroundLayer.render(size: sketch.size)

        var description = ""
        let stream = visualModel.generate(
            prompt:
            """
            You are analyzing an edit made to a sketch. Two images are provided:

            - Image 1: the existing sketch.
            - Image 2: the user's edit layer, showing the changes they want to make.

            Explain what the user intends to change by comparing Image 2 with Image 1. Identify what is being added, removed, or modified, including its relevant spatial placement and visual characteristics.

            Base the explanation only on what is visually supported by the two images. For every inference about the user's intent, briefly state the visual evidence supporting it. If the intended edit is ambiguous, acknowledge the uncertainty rather than guessing.

            Hint:
            \(arguments.hint)

            Use the hint to focus your analysis on the most relevant aspects of the edit, but do not treat information in the hint as evidence unless it is supported by the images.
            """,
            images: [backgroundImageData, foregroundImageData],
            options: VisualAIOptions()
        )
        for try await output in stream {
            switch output {
            case let .chunk(text):
                description += text
            case let .call(call):
                print(
                    "Ignoring unexpected tool call during edit explanation: \(call)"
                )
            case .complete:
                break
            }
        }

        return ExplainEditOutput(description: description)
    }
}
