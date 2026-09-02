//
//  AIModelFactory.swift
//  broche
//

import Foundation

/// A factory that creates AI model instances for text, visual, and image tasks.
///
/// Conform to this protocol to provide custom or mock model implementations.
/// See ``DefaultAIModelFactory`` for the default production implementation.
protocol AIModelFactory {
    var secrets: Secrets { get set }

    /// Creates a text generation model (LLM).
    func makeTextModel() -> TextAIModel
    /// Creates a visual language model (VLM) for image understanding.
    func makeVisualModel() -> VisualAIModel
    /// Creates an image editing model.
    func makeImageModel() -> ImageAIModel
}

/// Centralized factory for constructing AI model instances.
///
/// Encapsulates default model IDs and configuration so that callers
/// do not need to hard-code model identifiers throughout the codebase.
class DefaultAIModelFactory: AIModelFactory {
    // MARK: - Default Model IDs

    /// Default model ID used for text generation.
    static let defaultTextModelID = "qwen/qwen3-30b-a3b-instruct-2507"

    /// Default model ID used for visual text generation.
    static let defaultVisualModelID = "openai/gpt-5-nano"

    /// Default model ID used for image editing.
    static let defaultImageModelID = "black-forest-labs/flux-2-klein-9b"

    static let defaultSecrets = FirebaseSecrets.shared

    static let shared = DefaultAIModelFactory()

    /// Configurable secrets provider
    var secrets: Secrets

    init(secrets: Secrets = defaultSecrets) {
        self.secrets = secrets
    }

    // MARK: - Text Model

    func makeTextModel() -> TextAIModel {
        OpenRouterTextAIModel(modelID: Self.defaultTextModelID, secrets: secrets)
    }

    // MARK: - Visual Model

    func makeVisualModel() -> VisualAIModel {
        OpenRouterVisualAIModel(modelID: Self.defaultVisualModelID, secrets: secrets)
    }

    // MARK: - Image Model

    func makeImageModel() -> ImageAIModel {
        ReplicateImageAIModel(modelID: Self.defaultImageModelID, secrets: secrets)
    }
}
