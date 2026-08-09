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

    var errorDescription: String? {
        switch self {
        case .systemMessageProvided:
            return
                "System messages must not be provided to SketchAgent. The system message is injected automatically."
        }
    }
}

/// A specialized AI agent that interacts with a sketch, providing capabilities
/// to caption and render the sketch using specified AI models.
///
/// Unlike ``AIAgent``, ``SketchAgent`` injects its own system message automatically
/// and does not accept system messages in the initial `messages` parameter.
/// Providing a system message will result in a ``SketchAgentError/systemMessageProvided`` error.
///
/// The injected system message instructs the model to act as a helpful sketch assistant
/// focused on rendering, composition enhancement, and visual guidance.
class SketchAgent: AIAgent {
    /// The sketch this agent operates on.
    let sketch: Sketch

    /// The system message injected automatically for all sketch agent conversations.
    private static let systemMessage = Message(
        user: .system,
        text: """
            You are a helpful sketch assistant. Your role is to help the user with their \
            sketch by rendering it, enhancing its composition, and providing visual guidance. \
            Use the '\(CaptionTool.NAME)' tool to understand what the user has drawn, and the \
            '\(RenderTool.NAME)' tool to transform sketches into polished images. \
            Focus on composition, clarity, and artistic intent.
            """
    )

    /// Creates a new sketch agent for the given sketch with the specified AI models.
    ///
    /// A system message is injected automatically as the first message.
    /// Any system messages included in `messages` will cause a
    /// ``SketchAgentError/systemMessageProvided`` error.
    ///
    /// - Parameters:
    ///   - sketch: The sketch this agent will operate on.
    ///   - modelFactory: The factory used to create AI models for text, visual, and image tasks.
    ///   - messages: Optional conversation history. Must not contain any system messages.
    /// - Throws: ``SketchAgentError/systemMessageProvided`` if a system message is found,
    ///   or any error propagated from ``AIAgent/init(model:tools:messages:)``.
    init(
        sketch: Sketch,
        modelFactory: any AIModelFactory,
        messages: [Message] = []
    ) async throws {
        guard !messages.contains(where: { $0.user == .system }) else {
            throw SketchAgentError.systemMessageProvided
        }

        self.sketch = sketch

        // create & load models asynchronously
        let textModel = modelFactory.makeTextModel()
        async let textLoad = textModel.load()
        let visualModel = modelFactory.makeVisualModel()
        async let visualLoad = visualModel.load()
        let imageModel = modelFactory.makeImageModel()
        async let imageLoad = imageModel.load()
        _ = try await (textLoad, visualLoad, imageLoad)

        try super.init(
            model: textModel,
            tools: [
                CaptionTool(sketch: sketch, visualModel: visualModel),
                RenderTool(sketch: sketch, imageModel: imageModel),
            ],
            messages: [Self.systemMessage] + messages
        )
    }
}
