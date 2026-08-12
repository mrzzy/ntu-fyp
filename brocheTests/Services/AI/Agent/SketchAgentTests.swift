import Foundation
import FoundationModels
import Testing

@testable import broche

@Suite("SketchAgent mock tests")
@MainActor
struct SketchAgentTests {
    @Test("Throws error when system message is present in sketch messages")
    func throwsWhenSystemMessageProvided() async throws {
        let sketch = Sketch()
        sketch.messages.append(Message(user: .system, text: "should not be here"))

        let models = AIRepository(MockAIModelFactory())
        do {
            _ = try SketchAgent(
                sketch: sketch,
                models: models
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
                AIToolCall(id: "call_caption", name: CaptionTool.NAME, argsJSON: captionArgs),
                AIToolCall(id: "call_render", name: RenderTool.NAME, argsJSON: renderArgs),
            ],
            mockVisualCaption:
                "A sketch of an apple sliced on a plate with a cup at the side."
        )
        let models = AIRepository(factory)
        try await models.load()
        let agent = try await SketchAgent(sketch: sketch, models: models)

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

        #expect(
            !sketch.messages.contains(where: { $0.user == .system }),
            "Sketch messages should never contain system messages"
        )
        let sketchToolMessages = sketch.messages.filter { $0.user == .tool }
        #expect(
            sketchToolMessages.contains { $0.text.contains(CaptionTool.NAME) },
            "Sketch messages should contain caption tool result"
        )
        #expect(
            sketchToolMessages.contains { $0.text.contains(RenderTool.NAME) },
            "Sketch messages should contain render tool result"
        )
        #expect(
            sketch.messages.contains { $0.user == .ai },
            "Sketch messages should contain the final AI response"
        )
        #expect(
            sketch.messages.contains { $0.user == .user && $0.text.contains("watercolour") },
            "Sketch messages should contain the user prompt"
        )

        #expect(
            sketch.messages.first?.user == .ai
                && sketch.messages.first?.text.contains("AI art assistant") == true,
            "Sketch messages should start with the welcome message"
        )
    }

    @Test("Inserts welcome message on first instruct when sketch is empty")
    func insertsWelcomeMessageOnFirstInstruct() async throws {
        let sketch = Sketch()

        let factory = MockAIModelFactory(
            mockTextResponse: "Hello! How can I help with your sketch?"
        )
        let models = AIRepository(factory)
        try await models.load()
        let agent = try await SketchAgent(sketch: sketch, models: models)

        for try await _ in agent.instruct(
            prompt: "Hello!"
        ) {}

        let welcome = sketch.messages.first
        #expect(
            welcome?.user == .ai && welcome?.text.contains("AI art assistant") == true,
            "Agent should insert welcome message as first message on empty sketch"
        )
    }
}
