import Foundation
import Testing

@testable import broche

@Suite("ExplainEditTool integration tests")
@MainActor
struct ExplainEditToolIntegrationTests {
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

    @Test("Explains apple slice edit and returns non-empty description")
    func explainsAppleSliceEdit() async throws {
        let sketch = makeEditedSketch()
        let visualModel = DefaultAIModelFactory.shared.makeVisualModel()
        try await visualModel.load()

        let tool = ExplainEditTool(sketch: sketch, visualModel: visualModel)
        let output = try await tool.call(
            arguments: ExplainEditArguments(
                hint:
                    "Focus on what new elements have been drawn on top of the oil painting. Describe spatial placement and shapes."
            )
        )

        #expect(!output.description.isEmpty, "Explain edit output should not be empty")
        #expect(
            output.description.count > 10,
            "Description should be substantive, at least 10 characters"
        )
        print("Explain edit: \(output.description)")
    }

    @Test("Throws notEnoughLayers when sketch has fewer than 2 layers")
    func throwsNotEnoughLayers() async {
        let sketch = Sketch(
            title: "Single",
            layers: [
                .image(data: TestFixtures.appleAIOil)
            ], size: CGSize(width: 512, height: 512))
        let visualModel = DefaultAIModelFactory.shared.makeVisualModel()
        let tool = ExplainEditTool(sketch: sketch, visualModel: visualModel)

        await #expect(throws: ExplainEditToolError.self) {
            _ = try await tool.call(arguments: ExplainEditArguments(hint: ""))
        }
    }
}
