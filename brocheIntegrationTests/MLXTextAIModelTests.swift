//
//  MLXTextAIModelTests.swift
//  brocheTests
//
//  Created by Zhu Zhanyan on 2026-07-20.
//

import Foundation
import Testing

@testable import broche

/// use a small model with a tiny memory footprint for testing
let testModelID = "mlx-community/Qwen3-0.6B-4bit"

@Suite("MLXTextAIModel tests")
@MainActor
struct MLXTextAIModelTests {
    @Test("Generate throws modelNotLoaded when model is not loaded")
    func generateThrowsModelNotLoadedWhenNotLoaded() async {
        let model = MLXTextAIModel(modelID: testModelID)

        await #expect(throws: LLMError.self) {
            try await model.generate(
                prompt: "Hello",
                options: TextAIOptions()
            )
        }
    }

    @Test("Load throws for invalid model ID")
    func loadThrowsForInvalidModelID() async {
        let model = MLXTextAIModel(modelID: "invalid/model/id")

        await #expect(throws: Error.self) {
            try await model.load()
        }
    }

    @Test("Error descriptions are non-empty")
    func errorDescriptionsAreNonEmpty() {
        #expect(LLMError.modelNotLoaded.errorDescription != nil)
        #expect(
            LLMError.invalidModelPath("/some/path").errorDescription != nil
        )
    }

    @Test("Generate returns streaming response with metrics")
    func generateReturnsStreamingResponse() async throws {
        let model = MLXTextAIModel(modelID: testModelID, maxTokens: 1024)

        let result = try await benchmarkAI(model)
        print("\n\(result)")

        #expect(!result.response.isEmpty)
        #expect(result.loadTimeSecs > 0)
        #expect(result.wallClockGenTimeSecs > 0)
        if let metrics = result.metrics {
            #expect(metrics.nGenerationTokens > 0)
        }
    }
}
