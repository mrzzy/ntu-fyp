@testable import broche
import Foundation
import Testing

@Suite("SketchAgent integration tests")
@MainActor
struct SketchAgentIntegrationTests {
    @Test("Renders apple sketch as watercolour painting")
    func rendersAppleSketchAsWatercolour() async throws {
        let sketch = TestFixtures.sketch
        try await AIRepository.shared.load()
        let agent = try SketchAgent(
            sketch: sketch,
            models: AIRepository.shared,
        )

        var hasMessages = false
        for try await _ in agent.instruct(
            prompt: "Render the sketch in the style of a watercolour painting."
        ) {
            hasMessages = true
        }

        #expect(hasMessages, "Stream should yield messages")

        let toolMessages = sketch.messages.filter { $0.user == .tool }.map { $0.text }
        let captionUsed = toolMessages.contains { $0.contains(CaptionTool.NAME) }
        let renderUsed = toolMessages.contains { $0.contains(RenderTool.NAME) }
        #expect(captionUsed, "Agent should have called caption_sketch to understand the sketch")
        #expect(renderUsed, "Agent should have called render_sketch to produce the watercolour image")

        let hasAI = sketch.messages.contains { $0.user == .ai }
        #expect(hasAI, "Agent should produce a final AI response")

        #expect(sketch.layers.count > 1,
                "A new image layer should have been appended to the sketch")

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


        print("Final layers: \(sketch.layers.count)")
        for (i, msg) in sketch.messages.enumerated() {
            print("--- Message \(i) [\(msg.user)] ---")
            print("  \(msg.text)")
        }
    }

    @Test("Throws error when system message is present in sketch messages")
    func throwsWhenSystemMessageProvided() async throws {
        let sketch = Sketch()
        sketch.messages.append(Message(user: .system, text: "should not be here"))

        do {
            _ = try SketchAgent(
                sketch: sketch,
                models: AIRepository.shared
            )
            Issue.record("Expected SketchAgentError.systemMessageProvided to be thrown")
        } catch is SketchAgentError {
            // expected
        }
    }
}
