//
//  UzuTextAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-23.
//

import Foundation
import Uzu

/// Errors specific to ``UzuTextAIModel``.
enum UzuError: Error, LocalizedError {
    /// ``generate(prompt:options:)`` was called before ``load()`` succeeded.
    case engineNotInitialized
    /// The model identifier was not found in the Uzu model registry.
    case modelNotFound(modelID: String)

    var errorDescription: String? {
        switch self {
        case .engineNotInitialized:
            "Engine has not been initialized. Call load() first."
        case .modelNotFound(let id):
            "Model '\(id)' not found in the Uzu model registry"
        }
    }
}

/// A ``TextAIModel`` backed by [Uzu](https://github.com/trymirai/uzu) (Mirai).
///
/// `modelID` should be a HuggingFace model identifier recognized by Uzu
/// (e.g. `"Qwen/Qwen3-0.6B"`). The model is downloaded automatically on
/// ``load()`` if not already cached.
final class UzuTextAIModel: TextAIModel {
    let modelID: String
    let maxTokens: Int

    private var engine: Engine?
    private var model: Model?
    private var session: ChatSession?

    init(modelID: String, maxTokens: Int = 2048) {
        self.modelID = modelID
        self.maxTokens = maxTokens
    }

    /// Loads the model via the Uzu engine: looks up the model, downloads if needed,
    /// and creates a chat session ready for inference.
    ///
    /// - Throws: ``UzuError`` or any error from engine/model initialization.
    func load() async throws {
        let engine = try await Engine.create(config: .create())

        guard let model = try await engine.model(identifier: modelID) else {
            throw UzuError.modelNotFound(modelID: modelID)
        }
        self.model = model

        for try await _ in try await engine.download(model: model).iterator() {}
        self.engine = engine
    }

    func generate(
        prompt: String,
        options: TextAIOptions
    ) async throws -> AsyncThrowingStream<TextAIOutput, Error> {
        guard let engine, let model else {
            throw UzuError.engineNotInitialized
        }

        // create new chat session if none has been created
        if session == nil {
            session = try await engine.chat(
                model: model,
                config: .create().withSamplingSeed(samplingSeed: .custom(seed: Int64(options.seed)))
            )
        }

        let messages = [ChatMessage.user().withText(text: prompt)]
        let replyConfig = ChatReplyConfig.create().withTokenLimit(tokenLimit: UInt32(maxTokens))
        let stream = await session!.replyWithStream(input: messages, config: replyConfig)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var previousLength = 0
                    var lastReply: ChatReply?

                    for try await update in stream.iterator() {
                        switch update {
                        case .replies(let replies):
                            if let reply = replies.last {
                                lastReply = reply
                                let text = reply.message.text() ?? ""

                                if text.count > previousLength {
                                    let chunk = String(text.dropFirst(previousLength))
                                    if !chunk.isEmpty {
                                        continuation.yield(.chunk(text: chunk))
                                    }
                                    previousLength = text.count
                                }
                            }
                        case .error(let error):
                            continuation.finish(throwing: error)
                            return
                        }
                    }

                    continuation.yield(
                        .complete(
                            metrics: TextAIMetrics(
                                nPromptTokens: Int(lastReply?.stats.tokensCountInput ?? 0),
                                nGenerationTokens: Int(lastReply?.stats.tokensCountOutput ?? 0)
                            )
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
