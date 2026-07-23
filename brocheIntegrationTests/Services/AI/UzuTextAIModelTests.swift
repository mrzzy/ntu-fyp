//
//  UzuTextAIModelTests.swift
//  brocheIntegrationTests
//
//  Created by Zhu Zhanyan on 2026-07-23.
//

import Foundation
import Testing

@testable import broche

/// The HuggingFace model ID for ``Qwen3-0.6B``, a small model suitable for
/// integration testing.
private let testModelID = "Qwen/Qwen3-0.6B-MLX-4bit"

@Suite("UzuTextAIModel tests")
@MainActor
struct UzuTextAIModelTests {

    @Test("Generate throws engineNotInitialized when model is not loaded")
    func generateThrowsEngineNotInitializedWhenNotLoaded() async {
        let model = UzuTextAIModel(modelID: testModelID)

        await #expect(throws: UzuError.self) {
            try await model.generate(
                prompt: "Hello",
                options: TextAIOptions()
            )
        }
    }

    @Test("Error descriptions are non-empty")
    func errorDescriptionsAreNonEmpty() {
        #expect(UzuError.engineNotInitialized.errorDescription != nil)
        #expect(UzuError.modelNotFound(modelID: "test").errorDescription != nil)
    }

    @Test("Generate returns streaming response with metrics")
    func generateReturnsStreamingResponse() async throws {
        let model = UzuTextAIModel(modelID: testModelID, maxTokens: 1024)

        let result = try await benchmarkAI(
            model,
            prompt: "Explain how to paint a watercolor, step by step.",
            options: TextAIOptions(temperature: 1.0),
        )

        print("\n\(result)")

        #expect(!result.response.isEmpty)
        #expect(result.loadTimeSecs > 0)
        #expect(result.wallClockGenTimeSecs > 0)
        if let metrics = result.metrics {
            #expect(metrics.nGenerationTokens > 0)
        }
    }
}
