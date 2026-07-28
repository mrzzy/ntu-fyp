import Foundation
import Testing

@testable import broche

private let testModelID = "RepublicOfKorokke/Qwen3.5-4B-mlx-vlm-mxfp4"

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
        // Load test image from test bundle.
        let url = try #require(Bundle.main.url(
            forResource: "apple_sketch",
            withExtension: "png"
        ))

        let imageData = try Data(contentsOf: url)

        let model = MLXVisualAIModel(
            modelID: testModelID,
            maxTokens: 1024
        )
        try await model.load()

        let stream = model.generate(
            prompt: "Describe what the user is drawing in this sketch.",
            images: [imageData],
            options: VisualAIOptions()
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

        #expect(!response.isEmpty)
        #expect(metrics != nil)

        print(response)
        print(metrics!)
    }
}
