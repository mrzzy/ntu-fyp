@testable import broche
import Foundation
import Testing

private let testModelID = "openai/gpt-5-nano"

@Suite("OpenRouterVisualAIModel tests")
@MainActor
struct OpenRouterVisualAIModelTests {

    @Test("Generate throws modelNotLoaded when model is not loaded")
    func generateThrowsModelNotLoadedWhenNotLoaded() async {
        let model = OpenRouterVisualAIModel()

        await #expect(throws: OpenRouterVisualAIError.self) {
            for try await _ in model.generate(
                prompt: "Hello",
                images: [],
                options: VisualAIOptions()
            ) {}
        }
    }

    @Test("Load and Generate returns streaming response with metrics")
    func loadAndGenerateReturnsStreamingResponse() async throws {
        let model = OpenRouterVisualAIModel(modelID: testModelID)
        let benchmark = VisualAIBenchmark<OpenRouterVisualAIModel>()
        let result = try await benchmark.evaluate(model)

        print("Benchmark result: \(result)")
        #expect(result.loadSecs > 0)
        #expect(result.generateSecs > 0)
        guard case .visual = result.metrics else {
            Issue.record("Expected visual metrics, got \(result.metrics)")
            return
        }
        #expect(!benchmark.response.isEmpty)
        print("Response: \(benchmark.response)")
    }
}
