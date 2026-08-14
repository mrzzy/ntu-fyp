import Foundation
import Testing

@testable import broche

@Suite("RenderTool integration tests")
@MainActor
struct RenderToolIntegrationTests {
    @Test("Renders apple sketch in oil painting style and appends new layers")
    func rendersAppleSketchAsOilPainting() async throws {
        let sketch = TestFixtures.sketch
        let initialLayerCount = sketch.layers.count
        let imageModel = DefaultAIModelFactory.shared.makeImageModel()
        try await imageModel.load()

        let tool = RenderTool(sketch: sketch, imageModel: imageModel)
        let output = try await tool.call(
            arguments: RenderArguments(
                prompt:
                    "Oil painting style, thick impasto brushstrokes, rich warm palette, textured canvas, chiaroscuro lighting, classical still life composition."
            )
        )

        #expect(!output.message.isEmpty, "Render output message should not be empty")
        #expect(
            output.message.contains("Rendered layers"),
            "Output message should confirm which layers were rendered"
        )
        print("Render output: \(output.message)")

        #expect(
            sketch.layers.count == initialLayerCount + 2,
            "RenderTool should append an image layer and a blank drawing layer"
        )

        let lastImageLayer = sketch.layers[sketch.layers.count - 2]
        let topDrawingLayer = sketch.layers[sketch.layers.count - 1]
        if case let .image(imageData, _) = lastImageLayer {
            #expect(!imageData.isEmpty, "Rendered image data should not be empty")

            let documentsDir = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            )[0]
            let outputURL = documentsDir.appendingPathComponent(
                "RenderToolIntegrationTests_rendersAppleSketchAsOilPainting.png"
            )
            try imageData.write(to: outputURL)
            print("  Saved: \(outputURL.path)")
        } else {
            Issue.record("Expected an image layer at index \(sketch.layers.count - 2)")
        }
        if case .drawing = topDrawingLayer {
            // expected
        } else {
            Issue.record("Expected a drawing layer at index \(sketch.layers.count - 1)")
        }
    }

    @Test("Throws notEnoughLayers when sketch has no layers")
    func throwsNotEnoughLayers() async {
        let sketch = Sketch(title: "Empty", layers: [], size: CGSize(width: 512, height: 512))
        let imageModel = DefaultAIModelFactory.shared.makeImageModel()
        let tool = RenderTool(sketch: sketch, imageModel: imageModel)

        await #expect(throws: RenderToolError.self) {
            _ = try await tool.call(arguments: RenderArguments(prompt: "oil painting"))
        }
    }
}
