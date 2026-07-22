//
//  MLXTextAIModelTests.swift
//  brocheTests
//
//  Created by Zhu Zhanyan on 2026-07-20.
//

import Foundation
import Testing

@testable import broche

// use a small model with a tiny memory footprint for testing
let testModelID = "mlx-community/SmolLM-135M-Instruct-4bit"

@Suite("MLXTextAIModel tests")
@MainActor
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
            options: TextGenerationOptions(maxTokens: 16, temperature: 1.0)
        )

        var response = ""
        for try await chunk in stream {
            response += chunk
        }
        print(response)
        #expect(!response.isEmpty)
    }
}
