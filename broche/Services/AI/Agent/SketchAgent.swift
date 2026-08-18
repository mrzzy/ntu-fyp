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
/// to caption and render the sketch using specified AI models.
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
    /// SwiftData models repository
    let data: Repository = .shared
    /// The sketch this agent operates on.
    let sketch: Sketch
    /// Repository of AI models
    let models: AIRepository

    /// The system message injected automatically for all sketch agent conversations.
    private static func makeSystemMessage(hasChanges: Bool) -> Message {
        let changePrompt =
            if hasChanges {
                "The user has made new changes to the sketch since your last response. You must use the '\(CaptionTool.NAME)' tool first to update your understanding of the current sketch before providing further guidance."
            } else {
                ""
            }
        return Message(
            user: .system,
            text: """
                You are a sketch assistant. Your role is to help the user with their
                sketch by rendering or editing it, and providing visual guidance.
                If the user's message is ambiguous, ask for clarification.
                Focus on composition, clarity, and artistic intent.
                You may use tools to complete your task:
                1. Rendering Pipeline: [\(CaptionTool.NAME), \(RenderTool.NAME)]: Use these tools when user wants to render a final image (big scope).
                2. Editing Pipeline: [\(ExplainEditTool.NAME), \(EditTool.NAME)]: Use these tools when user wants to modify or refine the sketch (small scope).
                If the user cites a specific mood, use \(ListMoodTool.NAME) tool to list the moods and their corresponding style information.
                Do not use both \(EditTool.NAME) & \(RenderTool.NAME) when handling the same user message. Choose one based on the user's request.
                Do not be overly encouraging or verbose. Provide concise, actionable guidance.
                Try again there are transient failures eg. Request timed out.
                \(changePrompt)
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
                CaptionTool(sketch: sketch, visualModel: models.visualModel),
                ExplainEditTool(sketch: sketch, visualModel: models.visualModel),
                RenderTool(sketch: sketch, imageModel: models.imageModel),
                EditTool(sketch: sketch, imageModel: models.imageModel),
                ListMoodTool(repo: data),
            ],
            messages: [Self.makeSystemMessage(hasChanges: false)] + sketch.messages
        )
    }

    override func instruct(prompt: String) -> AsyncThrowingStream<Message, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // instruct model to pick up new changes if last caption call did not pick up new changes
                    let captionedOn = tools.invokedOn(forTool: CaptionTool.NAME) ?? .distantPast
                    self._messages[0] = Self.makeSystemMessage(
                        hasChanges: captionedOn < sketch.modifiedOn
                    )

                    for try await message in super.instruct(prompt: prompt) {
                        sketch.messages.append(message)
                        data.save()
                        continuation.yield(message)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
