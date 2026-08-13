//
//  SketchAgent
//  broche
//  Created by Zhu Zhanyan on 2026-07-28
//

import Foundation

/// Errors that can occur when initializing a ``SketchAgent``.
enum SketchAgentError: LocalizedError {
    /// A system message was provided in the initial messages, which is not allowed.
    /// The system message is injected automatically by the agent.
    case systemMessageProvided
    /// The AI models have not been loaded before initializing the agent.
    case modelsNotLoaded

    var errorDescription: String? {
        switch self {
        case .systemMessageProvided:
            return
                "System messages must not be provided to SketchAgent. The system message is injected automatically."
        case .modelsNotLoaded:
            return
                "AI models have not been loaded. Call load() on the AIRepository before initializing SketchAgent."
        }
    }
}

/// A specialized AI agent that interacts with a sketch, providing capabilities
/// to render the sketch using specified AI models.
///
/// Unlike ``AIAgent``, ``SketchAgent`` injects its own system message automatically
/// and uses the sketch's existing conversation history (``Sketch/messages``)
/// instead of accepting messages as a parameter.
/// Providing a system message in ``Sketch/messages`` will result in a
/// ``SketchAgentError/systemMessageProvided`` error.
///
/// The injected system message instructs the model to act as a helpful sketch assistant
/// focused on rendering, composition enhancement, and visual guidance.
class SketchAgent: AIAgent {
    /// The sketch this agent operates on.
    let sketch: Sketch
    let models: AIRepository

    /// The system message injected automatically for all sketch agent conversations.
    private static var systemMessage: Message {
        Message(
            user: .system,
            text: """
                You are a sketch assistant. Your role is to help the user with their \
                sketch by rendering it, enhancing its composition, and providing visual guidance. \
                All tools should be called only once per turn and only when necessary.
                Focus on composition, clarity, and artistic intent.
                Do not be overly encouraging or verbose. Provide concise, actionable guidance.
                """
        )
    }

    /// The welcome message inserted on the first ``instruct`` call.
    static let welcomeMessage = Message(
        user: .ai,
        text: """
            Hey! I'm your AI art assistant. I can help you refine your sketch and explore ideas.

            You can ask me to:
            • Modify, refine, or enhance parts of your sketch
            • Colorize and experiment with different styles
            • Render your ideas into more polished artwork
            • Discuss creative changes and improvements
            """
    )

    /// Creates a new sketch agent for the given sketch with the specified AI models.
    ///
    /// A system message is injected automatically as the first message.
    /// Any system messages present in ``Sketch/messages`` will cause a
    /// ``SketchAgentError/systemMessageProvided`` error.
    ///
    /// - Parameters:
    ///   - sketch: The sketch this agent will operate on. Its `messages` are used
    ///     as the conversation history.
    ///   - models: The AI models to use for text, visual, and image tasks.
    /// - Throws: ``SketchAgentError/systemMessageProvided`` if a system message is found
    ///   in the sketch's messages, ``SketchAgentError/modelsNotLoaded`` if the models
    ///   have not been loaded, or any error propagated from ``AIAgent/init(model:tools:messages:)``.
    init(
        sketch: Sketch,
        models: AIRepository
    ) throws {
        guard !sketch.messages.contains(where: { $0.user == .system }) else {
            throw SketchAgentError.systemMessageProvided
        }
        guard models.isLoaded else {
            throw SketchAgentError.modelsNotLoaded
        }

        self.sketch = sketch
        self.models = models

        super.init(
            model: models.textModel,
            tools: [
                RenderTool(sketch: sketch, imageModel: models.imageModel)
            ],
            messages: [Self.systemMessage] + sketch.messages
        )
    }

    override func instruct(prompt: String) -> AsyncThrowingStream<[Message], Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await messages in super.instruct(prompt: prompt) {
                        sketch.messages = messages
                        continuation.yield(messages)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
