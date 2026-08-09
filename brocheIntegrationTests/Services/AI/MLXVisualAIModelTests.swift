@testable import broche
import Foundation
import Testing

private let testModelID = DefaultAIModelFactory.defaultVisualModelID

@Suite("MLXVisualAIModel tests")
@MainActor
struct MLXVisualAIModelTests {
    @Test("Generate throws modelNotLoaded when model is not loaded")
    func generateThrowsModelNotLoadedWhenNotLoaded() async {
        let model = MLXVisualAIModel(modelID: testModelID)

        await #expect(throws: VisualAIError.self) {
            let stream = model.generate(
                prompt: "Hello",
                images: [],
                options: VisualAIOptions()
            )

            for try await _ in stream {}
        }
    }

    @Test("Load throws for invalid model ID")
    func loadThrowsForInvalidModelID() async {
        let model = MLXVisualAIModel(modelID: "invalid/model/id")

        await #expect(throws: Error.self) {
            try await model.load()
        }
    }

    @Test("Generate returns streaming response with metrics")
    func generateReturnsStreamingResponse() async throws {
        let model = MLXVisualAIModel(
            modelID: testModelID,
            maxTokens: 1024
        )
        let benchmark = VisualAIBenchmark<MLXVisualAIModel>()
        let result = try await benchmark.evaluate(model)

        print("Benchmark result: \(result)")
        #expect(result.loadSecs > 0)
        #expect(result.generateSecs > 0)
        guard case let .visual(metrics) = result.metrics else {
            Issue.record("Expected visual metrics, got \(result.metrics)")
            return
        }
        #expect(metrics.nGenerationTokens > 0)

        print("Response: \(benchmark.response)")
    }
}
