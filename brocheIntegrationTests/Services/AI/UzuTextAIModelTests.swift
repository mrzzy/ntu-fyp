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
    func generateThrowsEngineNotInitializedWhenNotLoaded() {
        let model = UzuTextAIModel(modelID: testModelID)

        #expect(throws: UzuError.self) {
            model.generate(
                prompt: "Hello",
                options: TextAIOptions()
            )
        }
    }

    @Test("Generate returns streaming response with metrics")
    func generateReturnsStreamingResponse() async throws {
        let model = UzuTextAIModel(modelID: testModelID, maxTokens: 1024)

        let result = try await benchmarkAI(model)

        print("\n\(result)")

        #expect(!result.response.isEmpty)
        #expect(result.loadTimeSecs > 0)
        #expect(result.genTimeSecs > 0)
        if let metrics = result.metrics {
            #expect(metrics.nGenerationTokens > 0)
        }
    }
}
