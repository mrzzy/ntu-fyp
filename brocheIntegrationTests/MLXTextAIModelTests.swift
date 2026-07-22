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
                options: TextAIOptions()
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

    func memoryFootprint() -> Float? {
        // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
        // complex for the Swift C importer, so we have to define them ourselves.
        let TASK_VM_INFO_COUNT = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(
            MemoryLayout.offset(of: \task_vm_info_data_t.min_address)!
                / MemoryLayout<integer_t>.size
        )
        var info = task_vm_info_data_t()
        var count = TASK_VM_INFO_COUNT
        let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard
            kr == KERN_SUCCESS,
            count >= TASK_VM_INFO_REV1_COUNT
        else { return nil }

        return Float(info.phys_footprint)
    }

    @Test("Generate returns streaming response with metrics")
    func generateReturnsStreamingResponse() async throws {
        let model = MLXTextAIModel()

        let memBefore = memoryFootprint()

        let loadStart = CFAbsoluteTimeGetCurrent()
        try await model.load(modelID: testModelID)
        let loadTime = CFAbsoluteTimeGetCurrent() - loadStart

        let prompt = "Hello"
        let options = TextAIOptions(maxTokens: 1024, temperature: 1.0)

        let genStart = CFAbsoluteTimeGetCurrent()
        let stream = try await model.generate(
            prompt: prompt, options: options
        )

        var response = ""
        var metrics: TextAIMetrics?
        for try await output in stream {
            switch output {
            case .chunk(let text):
                response += text
            case .complete(let m):
                metrics = m
            }
        }
        let genTime = CFAbsoluteTimeGetCurrent() - genStart

        let memAfterGen = memoryFootprint()

        print("\n--- MLXTextAIModel Performance ---")
        print("Model ID:             \(testModelID)")
        print("Load time:            \(String(format: "%.2f", loadTime))s")
        print("Latency:  \(String(format: "%.2f", genTime))s")
        if let metrics {
            print("Prompt tokens:        \(metrics.nPromptTokens)")
            print("Generated tokens:     \(metrics.nGenerationTokens)")
            let tokPerSec = genTime > 0 ? Double(metrics.nGenerationTokens) / genTime : 0
            print("TPS:      \(String(format: "%.2f", tokPerSec))")
        }
        let genMem = (memAfterGen.map { ($0 - memBefore!) / 1024 / 1024 } ?? nil)
        if let genMem {
            print("Memory Used:     \(String(format: "%.1f", genMem)) MB")
        }
        print("Response:             \(response.prefix(200))")

        #expect(!response.isEmpty)
        #expect(loadTime > 0)
        #expect(genTime > 0)
        if let metrics {
            #expect(metrics.nGenerationTokens > 0)
        }
    }
}
