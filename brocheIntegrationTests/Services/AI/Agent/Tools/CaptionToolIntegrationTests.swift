@testable import broche
import Foundation
import Testing


@Suite("CaptionTool integration tests")
@MainActor
struct CaptionToolIntegrationTests {

    @Test("Captions apple sketch and returns non-empty description")
    func captionsAppleSketch() async throws {
        let sketch = TestFixtures.sketch
        let visualModel = DefaultAIModelFactory.shared.makeVisualModel()
        try await visualModel.load()

        let tool = CaptionTool(sketch: sketch, visualModel: visualModel)
        let output = try await tool.call(arguments: CaptionArguments(hint: "Identify the main subject."))
        #expect(!output.description.isEmpty, "Caption output should not be empty")
        print("Caption: \(output.description)")
    }

    @Test("Throws notEnoughLayers when sketch has no layers")
    func throwsNotEnoughLayers() async {
        let sketch = Sketch(title: "Empty", layers: [], size: CGSize(width: 512, height: 512))
        let visualModel = DefaultAIModelFactory.shared.makeVisualModel()
        let tool = CaptionTool(sketch: sketch, visualModel: visualModel)

        await #expect(throws: CaptionToolError.self) {
            _ = try await tool.call(arguments: CaptionArguments(hint: ""))
        }
    }
}
