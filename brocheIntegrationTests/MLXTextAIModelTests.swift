//
//  MLXTextAIModelTests.swift
//  brocheIntegrationTests
//
//  Created by Zhu Zhanyan on 2026-07-20.
//

@testable import broche
import Foundation
import Testing

/// use a small model with a tiny memory footprint for testing
private let testModelID = DefaultAIModelFactory.defaultTextModelID

@Suite("MLXTextAIModel tests")
@MainActor
struct MLXTextAIModelTests {
    @Test("Generate throws modelNotLoaded when model is not loaded")
    func generateThrowsModelNotLoadedWhenNotLoaded() async {
        let model = MLXTextAIModel(modelID: testModelID)

        await #expect(throws: LLMError.modelNotLoaded) {
            for try await _ in model.generate(
                messages: [
                    Message(user: .system, text: "You are a helpful assistant."),
                    Message(user: .user, text: "Explain how to paint a watercolor, step by step"),
                ],
                options: TextAIOptions()
            ) {}
        }
    }

    @Test("Load throws for invalid model ID")
    func loadThrowsForInvalidModelID() async {
        let model = MLXTextAIModel(modelID: "invalid/model/id")

        await #expect(throws: Error.self) {
            try await model.load()
        }
    }


    @Test("Generate returns streaming response with metrics")
    func generateReturnsStreamingResponse() async throws {
        let model = MLXTextAIModel(modelID: testModelID, maxTokens: 80000)
        let benchmark = TextAIBenchmark<MLXTextAIModel>()
        let metrics = try await benchmark.evaluate(model)

        print("Benchmark result: \(metrics)")
        #expect(metrics.loadSecs > 0)
        #expect(metrics.generateSecs > 0)
        guard case let .text(textMetrics) = metrics.metrics else {
            Issue.record("Expected text metrics, got \(metrics.metrics)")
            return
        }
        #expect(textMetrics.nGenerationTokens > 0)

        print("Response: \(benchmark.response)")
    }
}
