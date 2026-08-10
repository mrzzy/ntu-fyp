import Foundation
import Testing

@testable import broche

private let testModelID = "qwen/qwen3-30b-a3b-instruct-2507"

@Suite("OpenRouterTextAIModel tests")
@MainActor
struct OpenRouterTextAIModelTests {

    @Test("Generate throws modelNotLoaded when model is not loaded")
    func generateThrowsModelNotLoadedWhenNotLoaded() async {
        let model = OpenRouterTextAIModel()

        await #expect(throws: OpenRouterTextAIError.self) {
            for try await _ in model.generate(
                messages: [],
                options: TextAIOptions()
            ) {}
        }
    }

    @Test("Load and Generate returns non-empty text")
    func loadAndGenerateReturnsText() async throws {
        let model = OpenRouterTextAIModel(modelID: testModelID)
        let benchmark = TextAIBenchmark<OpenRouterTextAIModel>()
        let result = try await benchmark.evaluate(model)

        print("Benchmark result: \(result)")
        #expect(result.loadSecs > 0)
        #expect(result.generateSecs > 0)
        guard case .text = result.metrics else {
            Issue.record("Expected text metrics, got \(result.metrics)")
            return
        }
        #expect(!benchmark.response.isEmpty)
        print(benchmark.response)
    }
}
