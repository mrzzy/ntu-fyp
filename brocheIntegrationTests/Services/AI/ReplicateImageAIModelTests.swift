import Foundation
import Testing

@testable import broche

private let testModelID = DefaultAIModelFactory.defaultImageModelID

@Suite("ReplicateImageAIModel tests")
@MainActor
struct ReplicateImageAIModelTests {

    @Test("Edit throws modelNotLoaded when model is not loaded")
    func editThrowsModelNotLoadedWhenNotLoaded() async {
        let model = ReplicateImageAIModel()

        await #expect(throws: ReplicateImageAIError.self) {
            for try await _ in model.edit(
                images: [Data()], prompt: "a cat", options: ImageAIOptions()
            ) {}
        }
    }

    @Test("Load throws error for unresolved model ID")
    func loadThrowsForUnresolvedModelID() async {
        let model = ReplicateImageAIModel(modelID: "nonexistent-model-xyz")

        await #expect(throws: Error.self) {
            try await model.load()
        }
    }

    @Test("Load and Edit returns non-empty image data")
    func loadAndEditReturnsImage() async throws {
        let model = ReplicateImageAIModel(modelID: testModelID)
        let benchmark = ImageAIBenchmark<ReplicateImageAIModel>()
        let result = try await benchmark.evaluate(model)

        print("Benchmark result: \(result)")
        #expect(result.loadSecs > 0)
        #expect(result.generateSecs > 0)
        guard case .image(let metrics) = result.metrics else {
            Issue.record("Expected image metrics, got \(result.metrics)")
            return
        }
        #expect(metrics.nSamples > 0)

        guard let outputImage = benchmark.outputImage else {
            Issue.record("Benchmark did not produce output image")
            return
        }
        #expect(!outputImage.isEmpty)

        let documentsDir = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0]
        let outputURL = documentsDir.appendingPathComponent(
            "ReplicateImageAIModelTests_loadAndEditReturnsImage.png"
        )
        try outputImage.write(to: outputURL)
        print("  Saved: \(outputURL.path)")
    }
}

