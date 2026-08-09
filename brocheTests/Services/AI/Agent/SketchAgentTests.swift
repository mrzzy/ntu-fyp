import Foundation
import FoundationModels
import Testing

@testable import broche

@Suite("SketchAgent mock tests")
@MainActor
struct SketchAgentTests {
    @Test("Throws error when system message is provided in messages")
    func throwsWhenSystemMessageProvided() async throws {
        let factory = MockAIModelFactory()
        do {
            _ = try await SketchAgent(
                sketch: Sketch(),
                modelFactory: factory,
                messages: [Message(user: .system, text: "should not be here")]
            )
            Issue.record("Expected SketchAgentError.systemMessageProvided to be thrown")
        } catch is SketchAgentError {
            // expected
        }
    }

    @Test("Agent calls caption and render tools then produces final AI response")
    func agentCallsCaptionAndRenderTools() async throws {
        let sketch = TestFixtures.sketch

        let captionArgs = CaptionArguments(layerStart: nil, layerEnd: nil)
            .generatedContent.jsonString
        let renderArgs = RenderArguments(
            layerStart: nil,
            layerEnd: nil,
            prompt: "Render the sketch in the style of a watercolour painting."
        ).generatedContent.jsonString

        let factory = MockAIModelFactory(
            mockTextResponse: "I've rendered your sketch into a watercolour painting.",
            mockTextToolCalls: [
                AIToolCall(name: CaptionTool.NAME, argsJSON: captionArgs),
                AIToolCall(name: RenderTool.NAME, argsJSON: renderArgs),
            ],
            mockVisualCaption:
                "A sketch of an apple sliced on a plate with a cup at the side."
        )

        let agent = try await SketchAgent(sketch: sketch, modelFactory: factory)

        var finalMessages: [Message]?
        for try await snapshot in agent.instruct(
            prompt: "Render the sketch in the style of a watercolour painting."
        ) {
            finalMessages = snapshot
        }

        guard let messages = finalMessages else {
            Issue.record("Stream did not yield any messages")
            return
        }

        let toolMessages = messages.filter { $0.user == .tool }
        let captionUsed = toolMessages.contains { $0.text.contains(CaptionTool.NAME) }
        let renderUsed = toolMessages.contains { $0.text.contains(RenderTool.NAME) }
        #expect(
            captionUsed,
            "Agent should have called caption_sketch to understand the sketch"
        )
        #expect(
            renderUsed,
            "Agent should have called render_sketch to produce the watercolour image"
        )

        let hasAI = messages.contains { $0.user == .ai }
        #expect(hasAI, "Agent should produce a final AI response")

        #expect(
            sketch.layers.count > 0,
            "A new image layer should have been appended to the sketch"
        )
    }
}
