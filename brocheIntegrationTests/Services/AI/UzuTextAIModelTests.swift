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

        await #expect(throws: UzuError.engineNotInitialized) {
            for try await _ in model.generate(
                prompt: "Hello",
                options: TextAIOptions()
            ) {}
        }
    }

    @Test("Generate returns streaming response with metrics")
    func generateReturnsStreamingResponse() async throws {
        let model = UzuTextAIModel(modelID: testModelID, maxTokens: 1024)
        let benchmark = TextAIBenchmark<UzuTextAIModel>()
        let metrics = try await benchmark.evaluate(model)

        print("Benchmark result: \(metrics)")
        #expect(metrics.loadSecs > 0)
        #expect(metrics.generateSecs > 0)
        guard case .text(let textMetrics) = metrics.metrics else {
            Issue.record("Expected text metrics, got \(metrics.metrics)")
            return
        }
        #expect(textMetrics.nGenerationTokens > 0)

        print("Response: \(benchmark.response)")
    }
}
