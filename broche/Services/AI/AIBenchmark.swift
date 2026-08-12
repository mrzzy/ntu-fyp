//
//  AIBenchmark.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-22
//

import Foundation

/// AI model metrics that can be reported during text, visual, or image generation.
enum AIMetrics {
    case text(TextAIMetrics)
    case visual(VisualAIMetrics)
    case image(ImageAIMetrics)
}

/// The result of benchmarking a ``AIModel``.
///
/// Contains wall-clock timings, model-reported metrics, memory usage.
struct AIBenchmarkResult {
    /// The identifier of the model that was benchmarked.
    var modelID: String
    /// Wall-clock time taken to load the model, in seconds.
    var loadSecs: Double
    /// Wall-clock time from the start of generation to the final token, in seconds.
    var generateSecs: Double
    /// Memory used before the model was loaded in bytes
    var memoryUnloaded: UInt64
    /// Memory used after the model was loaded in bytes
    var memoryLoaded: UInt64
    /// Memory used when then model is generating output in bytes
    var memoryGenerate: UInt64
    /// Model-specific metrics
    var metrics: AIMetrics
}

enum AIBenchmarkError: Error {
    case MemoryFootprintUnavailable
    case NoMetricsReported

    var description: String {
        switch self {
        case .MemoryFootprintUnavailable:
            return "Unable to retrieve memory footprint."
        case .NoMetricsReported:
            return "The model did not report any metrics."
        }
    }
}

extension AIBenchmarkResult: CustomStringConvertible {
    var description: String {
        var lines: [String] = []
        lines.append("--- Benchmark: \(modelID) ---")
        lines.append("Load time:       \(String(format: "%.2f", loadSecs))s")
        lines.append("Latency:         \(String(format: "%.2f", generateSecs))s")
        switch metrics {
        case .text(let m), .visual(let m):
            lines.append("Prompt tokens:   \(m.nPromptTokens)")
            lines.append("Generated tokens:\(m.nGenerationTokens)")
            let tps =
                generateSecs > 0
                ? Double(m.nGenerationTokens) / generateSecs : 0
            lines.append("TPS:             \(String(format: "%.2f", tps))")
        case .image(let m):
            lines.append("Samples:         \(m.nSamples)")
        }
        let memoryUsedMB = (Double(memoryLoaded) - Double(memoryUnloaded)) / 1024 / 1024
        lines.append("Memory Used:     \(String(format: "%.1f", memoryUsedMB)) MB")
        let memoryPeakMB = Double(memoryGenerate) / 1024 / 1024
        lines.append("Memory Peak:     \(String(format: "%.1f", memoryPeakMB)) MB")
        lines.append("---------------------------")
        return lines.joined(separator: "\n")
    }
}

/// An AIModel benchmark
protocol AIBenchmark {
    associatedtype Model: AIModel

    /// Generate some output with with a fixed benchmark input to measure performance.
    func generate(_ model: Model) async throws -> AIMetrics
}

extension AIBenchmark {
    /// Evaluates a ``AI Model`` by loading it, text, and collecting performance metrics
    ///
    /// - Parameters:
    ///   - model: Any conformer to ``TextAIModel``.
    /// - Returns: A ``AIBenchmarkResult`` containing timings, metrics, memory usage, and the response.
    /// - Throws: Any error from model loading or text generation.
    func evaluate(_ model: Model) async throws -> AIBenchmarkResult {
        let memUnloaded = try memoryFootprint()
        let loadStart = CFAbsoluteTimeGetCurrent()
        try await model.load()
        let loadTime = CFAbsoluteTimeGetCurrent() - loadStart
        let memLoaded = try memoryFootprint()

        // evaluate benchmark worlload
        let genStart = CFAbsoluteTimeGetCurrent()
        let metrics = try await generate(model)
        let genTime = CFAbsoluteTimeGetCurrent() - genStart
        let memGenerate = try memoryFootprint()

        return AIBenchmarkResult(
            modelID: model.modelID,
            loadSecs: loadTime,
            generateSecs: genTime,
            memoryUnloaded: memUnloaded,
            memoryLoaded: memLoaded,
            memoryGenerate: memGenerate,
            metrics: metrics
        )
    }
}

/// Returns the current process's physical memory footprint in bytes, or `nil` if unavailable.
private func memoryFootprint() throws -> UInt64 {
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
    else { throw AIBenchmarkError.MemoryFootprintUnavailable }

    return info.phys_footprint
}
