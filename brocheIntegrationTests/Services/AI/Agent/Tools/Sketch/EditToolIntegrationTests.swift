import Foundation
import Testing

@testable import broche

@Suite("EditTool integration tests")
@MainActor
struct EditToolIntegrationTests {
    private func makeEditedSketch() -> Sketch {
        Sketch(
            title: "Apple Oil Edit",
            layers: [
                .image(data: TestFixtures.appleAIOil),
                .image(data: TestFixtures.appleAIOilEdit),
            ],
            size: CGSize(width: 512, height: 512)
        )
    }

    @Test("Applies apple slice edit and appends new layers")
    func appliesAppleSliceEdit() async throws {
        let sketch = makeEditedSketch()
        let initialLayerCount = sketch.layers.count
        let imageModel = DefaultAIModelFactory.shared.makeImageModel()
        try await imageModel.load()

        let tool = EditTool(sketch: sketch, imageModel: imageModel)
        let output = try await tool.call(
            arguments: EditArguments(
                prompt:
                    "Slice open the apple along its boundary lines and place the sliced apple on the table surface visible in the painting."
            )
        )

        #expect(!output.message.isEmpty, "Edit output message should not be empty")
        print("Edit output: \(output.message)")

        #expect(
            sketch.layers.count == initialLayerCount + 2,
            "EditTool should append an image layer and a blank drawing layer"
        )

        let lastImageLayer = sketch.layers[sketch.layers.count - 2]
        let topDrawingLayer = sketch.layers[sketch.layers.count - 1]
        if case .image(let imageData, _) = lastImageLayer {
            #expect(!imageData.isEmpty, "Edited image data should not be empty")

            let documentsDir = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            )[0]
            let outputURL = documentsDir.appendingPathComponent(
                "EditToolIntegrationTests_appliesAppleSliceEdit.png"
            )
            try imageData.write(to: outputURL)
            print("  Saved: \(outputURL.path)")
        } else {
            Issue.record("Expected an image layer at index \(sketch.layers.count - 2)")
        }
        if case .drawing = topDrawingLayer {
        } else {
            Issue.record("Expected a drawing layer at index \(sketch.layers.count - 1)")
        }
    }

    @Test("Throws notEnoughLayers when sketch has fewer than 2 layers")
    func throwsNotEnoughLayers() async {
        let sketch = Sketch(
            title: "Single",
            layers: [
                .image(data: TestFixtures.appleAIOil)
            ], size: CGSize(width: 512, height: 512))
        let imageModel = DefaultAIModelFactory.shared.makeImageModel()
        let tool = EditTool(sketch: sketch, imageModel: imageModel)

        await #expect(throws: EditToolError.self) {
            _ = try await tool.call(arguments: EditArguments(prompt: "slice the apple"))
        }
    }
}
