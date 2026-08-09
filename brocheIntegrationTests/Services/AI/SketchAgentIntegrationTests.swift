@testable import broche
import Foundation
import Testing

@Suite("SketchAgent integration tests")
@MainActor
struct SketchAgentIntegrationTests {
    @Test("Renders apple sketch as watercolour painting")
    func rendersAppleSketchAsWatercolour() async throws {
        let sketch = TestFixtures.sketch
        let agent = try await SketchAgent(
            sketch: sketch,
            modelFactory: DefaultAIModelFactory.shared
        )

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

        let toolMessages = messages.filter { $0.user == .tool }.map { $0.text }
        let captionUsed = toolMessages.contains { $0.contains(CaptionTool.NAME) }
        let renderUsed = toolMessages.contains { $0.contains(RenderTool.NAME) }
        #expect(captionUsed, "Agent should have called caption_sketch to understand the sketch")
        #expect(renderUsed, "Agent should have called render_sketch to produce the watercolour image")

        let hasAI = messages.contains { $0.user == .ai }
        #expect(hasAI, "Agent should produce a final AI response")

        #expect(sketch.layers.count > 1,
                "A new image layer should have been appended to the sketch")

        print("Final layers: \(sketch.layers.count)")
        for (i, msg) in messages.enumerated() {
            print("--- Message \(i) [\(msg.user.rawValue)] ---")
            print("  \(msg.text)")
        }
    }

    @Test("Throws error when system message is provided in messages")
    func throwsWhenSystemMessageProvided() async throws {
        do {
            _ = try await SketchAgent(
                sketch: Sketch(),
                modelFactory: DefaultAIModelFactory.shared,
                messages: [Message(user: .system, text: "should not be here")]
            )
            Issue.record("Expected SketchAgentError.systemMessageProvided to be thrown")
        } catch is SketchAgentError {
            // expected
        }
    }
}
