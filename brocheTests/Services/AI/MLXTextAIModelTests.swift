//
//  MLXTextAIModelTests.swift
//  brocheTests
//
//  Created by Zhu Zhanyan on 2026-07-20.
//

@testable import broche
import Foundation
import Testing

let testModelID = "mlx-community/Qwen3-0.6B-4bit"

@Suite("MLXTextAIModel tests")
struct MLXTextAIModelTests {

    @Test("Generate throws modelNotLoaded when model is not loaded")
    func generateThrowsModelNotLoadedWhenNotLoaded() async {
        let model = MLXTextAIModel()

        await #expect(throws: LLMError.self) {
            try await model.generate(
                prompt: "Hello",
                options: TextGenerationOptions()
            )
        }
    }

    @Test("Load throws for invalid model ID")
    func loadThrowsForInvalidModelID() async {
        let model = MLXTextAIModel()

        await #expect(throws: Error.self) {
            try await model.load(modelID: "invalid/model/id")
        }
    }

    @Test("Error descriptions are non-empty")
    func errorDescriptionsAreNonEmpty() {
        #expect(LLMError.modelNotLoaded.errorDescription != nil)
        #expect(
            LLMError.invalidModelPath("/some/path").errorDescription != nil
        )
    }

    @Test("Generate returns streaming response")
    func generateReturnsStreamingResponse() async throws {
        let model = MLXTextAIModel()
        try await model.load(modelID: testModelID)

        let stream = try await model.generate(
            prompt: "Hello",
            options: TextGenerationOptions(maxTokens: 16, temperature: 0.5)
        )

        var response = ""
        for try await chunk in stream {
            response += chunk
        }
        print(response)
        #expect(!response.isEmpty)
    }

    @Test("Generate handles empty prompt", .disabled("Requires network download"))
    func generateHandlesEmptyPrompt() async throws {
        let model = MLXTextAIModel()
        try await model.load(modelID: testModelID)

        let stream = try await model.generate(
            prompt: "",
            options: TextGenerationOptions()
        )

        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        #expect(!chunks.isEmpty)
    }
}
