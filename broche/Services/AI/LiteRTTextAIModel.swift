//
//  LiteRTTextAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-23.
//

import Foundation
import LiteRTLM

/// Errors specific to ``LiteRTTextAIModel``.
enum LiteRTError: Error, LocalizedError {
    /// ``generate(prompt:options:)`` was called before ``load(modelID:patterns:)`` succeeded.
    case engineNotInitialized
    /// The downloaded HuggingFace snapshot contained no `.litertlm` model file.
    case modelFileNotFound(modelID: String)

    var errorDescription: String? {
        switch self {
        case .engineNotInitialized:
            "Engine has not been initialized. Call load(modelID:) first."
        case .modelFileNotFound(let id):
            "No .litertlm model file found for '\(id)'"
        }
    }
}

/// A ``TextAIModel`` backed by Google's [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) runtime.
///
/// `load` accepts either a local file path to a `.litertlm` model or a
/// HuggingFace repository ID (e.g. `"google/gemma-4-2b-it-litert"`).
/// In the latter case the model is downloaded automatically via ``HuggingFaceDownloader``.
final class LiteRTTextAIModel: TextAIModel {
    /// Downloader used to fetch models from HuggingFace Hub.
    private let downloader = HuggingFaceDownloader()
    /// The underlying LiteRT engine, or `nil` if the model has not been loaded.
    private var engine: Engine?

    /// Loads a LiteRT-LM model from a local path or HuggingFace repository.
    ///
    /// If `modelID` is an existing file path it is used directly.
    /// Otherwise it is treated as a HuggingFace repo ID and the snapshot is
    /// downloaded with `patterns` as glob filters. The first file whose name
    /// ends with `"litertlm"` in the snapshot is passed to the LiteRT engine.
    ///
    /// - Parameters:
    ///   - modelID: A local `.litertlm` file path or a HuggingFace repository ID.
    ///   - patterns: Glob patterns to filter files when downloading from the Hub.
    /// - Throws: ``LiteRTError`` or any error from downloading or engine initialization.
    func load(modelID: String, patterns: [String] = ["*.litertlm"]) async throws {
        let modelPath: String
        let fm = FileManager.default

        if fm.fileExists(atPath: modelID) {
            modelPath = modelID
        } else {
            let snapshotDir = try await downloader.downloadSnapshot(
                repoID: modelID,
                matching: patterns
            )
            guard let file = downloader.findFile(in: snapshotDir, withSuffix: "litertlm")
            else {
                throw LiteRTError.modelFileNotFound(modelID: modelID)
            }
            modelPath = file.path
        }

        let config = try EngineConfig(
            modelPath: modelPath,
            backend: .gpu,
            cacheDir: NSTemporaryDirectory()
        )
        let engine = Engine(engineConfig: config)
        try await engine.initialize()
        self.engine = engine
    }

    func generate(
        prompt: String,
        options: TextAIOptions
    ) async throws -> AsyncThrowingStream<TextAIOutput, Error> {
        guard let engine else {
            throw LiteRTError.engineNotInitialized
        }

        let samplerConfig = try SamplerConfig(
            topK: 50,
            topP: 1.0,
            temperature: options.temperature
        )
        let conversationConfig = ConversationConfig(samplerConfig: samplerConfig)
        let conversation = try await engine.createConversation(with: conversationConfig)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var nGenerationTokens = 0
                    for try await chunk in conversation.sendMessageStream(LiteRTLM.Message(prompt)) {
                        if let firstContent = chunk.contents.first {
                            if case let .text(text) = firstContent {
                                if !text.isEmpty {
                                    continuation.yield(.chunk(text: text))
                                    nGenerationTokens += 1
                                }
                            }
                        }
                    }
                    continuation.yield(.complete(metrics: TextAIMetrics(
                        nPromptTokens: 0,
                        nGenerationTokens: nGenerationTokens
                    )))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
