//
//  DescribeMood.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-08-17.
//

import Foundation
import FoundationModels

enum DescribeMoodError: Error, LocalizedError {
    case noImagesProvided

    var errorDescription: String? {
        switch self {
        case .noImagesProvided:
            return "No images were provided to generate a mood caption."
        }
    }
}

@Generable
struct DescribeOutput: Codable, Sendable {
    @Guide(description: "A short, evocative title for the mood based on the provided images.")
    let title: String

    @Guide(
        description:
            "A detailed description of the mood, capturing the visual atmosphere, colors, style, and overall feeling conveyed by the images. Do not discuss subject matter, focus on transferable attributes."
    )
    let description: String
}

func describeMood(images: [Data], visualModel: VisualAIModel) async throws -> DescribeOutput {
    guard !images.isEmpty else {
        throw DescribeMoodError.noImagesProvided
    }

    let prompt = """
        Analyze the provided images together as a single, consistent visual mood.

        Identify the shared visual language across all images, including color, lighting, atmosphere, composition, texture, style, and emotional tone. Treat the images as references for one unified mood, not as separate subjects.
        Do not discuss subject matter, focus on transferable attributes.

        Respond in this as JSON string conforming to exact schema:
        \(DescribeOutput.generationSchema)
        """

    var response = ""
    let stream = visualModel.generate(
        prompt: prompt,
        images: images,
        options: VisualAIOptions()
    )
    for try await output in stream {
        switch output {
        case .chunk(let text):
            response += text
        case .call(let call):
            print("Ignoring unexpected tool call during mood caption generation: \(call)")
        case .complete:
            break
        }
    }

    let content = try GeneratedContent(json: response)
    return try DescribeOutput(content)
}
