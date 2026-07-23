//
//  LiteRTTextAIModelTests.swift
//  brocheIntegrationTests
//
//  Created by Zhu Zhanyan on 2026-07-23.
//

import Foundation
import Testing

@testable import broche

/// The HuggingFace model ID for the ``Qwen3-0.6B`` INT4 LiteRT-LM conversion.
///
/// This is a ~332 MB quantized model suitable for integration testing.
private let testModelID = "litert-community/Qwen3-0.6B-int4"

/// Downloads only the thinking-on variant of the model.
private let testPatterns: [String] = ["qwen3_0.6b_q4_block32_ekv1280.litertlm"]

@Suite("LiteRTTextAIModel tests")
@MainActor
struct LiteRTTextAIModelTests {
    @Test("Generate throws engineNotInitialized when model is not loaded")
    func generateThrowsEngineNotInitializedWhenNotLoaded() async {
        let model = LiteRTTextAIModel(modelID: testModelID, patterns: testPatterns)

        await #expect(throws: LiteRTError.self) {
            try await model.generate(
                prompt: "Hello",
                options: TextAIOptions()
            )
        }
    }

    @Test("Error descriptions are non-empty")
    func errorDescriptionsAreNonEmpty() {
        #expect(LiteRTError.engineNotInitialized.errorDescription != nil)
        #expect(LiteRTError.modelFileNotFound(modelID: "test").errorDescription != nil)
    }

    @Test("Generate returns streaming response with metrics")
    func generateReturnsStreamingResponse() async throws {
        let model = LiteRTTextAIModel(modelID: testModelID, patterns: testPatterns, maxTokens: 1024)

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
