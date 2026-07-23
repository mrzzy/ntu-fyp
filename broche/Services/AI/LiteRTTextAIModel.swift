//
//  LiteRTTextAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-23.
//

import Foundation
import HuggingFace
import LiteRTLM

/// Errors specific to ``LiteRTTextAIModel``.
enum LiteRTError: Error, LocalizedError {
    /// ``generate(prompt:options:)`` was called before ``load(modelID:patterns:)`` succeeded.
    case engineNotInitialized
    /// The downloaded HuggingFace snapshot contained no `.litertlm` model file.
    case modelFileNotFound(modelID: String)
    /// The given string is not a valid HuggingFace repository identifier.
    case invalidRepositoryID(String)

    var errorDescription: String? {
        switch self {
        case .engineNotInitialized:
            "Engine has not been initialized. Call load(modelID:) first."
        case .modelFileNotFound(let id):
            "No .litertlm model file found for '\(id)'"
        case .invalidRepositoryID(let id):
            "Invalid HuggingFace repository ID: \(id)"
        }
    }
}

/// A ``TextAIModel`` backed by Google's [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) runtime.
///
/// `load` accepts either a local file path to a `.litertlm` model or a
/// HuggingFace repository ID (e.g. `"google/gemma-4-2b-it-litert"`).
/// In the latter case the model is downloaded automatically via ``HubClient``.
final class LiteRTTextAIModel: TextAIModel {
    let modelID: String
    let patterns: [String]
    let maxTokens: Int
    
    /// The underlying LiteRT engine, or `nil` if the model has not been loaded.
    private var engine: Engine?

    init(modelID: String, patterns: [String] = ["*.litertlm"], maxTokens: Int = 2048) {
        self.modelID = modelID
        self.maxTokens = maxTokens
        self.patterns = patterns
    }
    

    /// Loads a LiteRT-LM model from a local path or HuggingFace repository.
    ///
    /// - Throws: ``LiteRTError`` or any error from downloading or engine initialization.
    func load() async throws {
        let modelPath: String
        let fm = FileManager.default

        // download model
        if fm.fileExists(atPath: modelID) {
            modelPath = modelID
        } else {
            let hubClient = HubClient.default
            guard let repo = Repo.ID(rawValue: modelID) else {
                throw LiteRTError.invalidRepositoryID(modelID)
            }
            let snapshotDir = try await hubClient.downloadSnapshot(
                of: repo,
                matching: patterns
            )
            guard let file = Filesystem.findFile(in: snapshotDir, withSuffix: "litertlm")
            else {
                throw LiteRTError.modelFileNotFound(modelID: modelID)
            }
            modelPath = file.path
        }

        // enable benchmarking experimental feature
        ExperimentalFlags.optIntoExperimentalAPIs()
        ExperimentalFlags.enableBenchmark = true

        let config = try EngineConfig(
            modelPath: modelPath,
            backend: .gpu,
            maxNumTokens: maxTokens,
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
            temperature: options.temperature,
            seed: options.seed,
        )
        let conversationConfig = ConversationConfig(samplerConfig: samplerConfig)
        let conversation = try await engine.createConversation(with: conversationConfig)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var nGenerationTokens = 0
                    for try await chunk in conversation.sendMessageStream(LiteRTLM.Message(prompt))
                    {
                        if let firstContent = chunk.contents.first {
                            if case .text(let text) = firstContent {
                                if !text.isEmpty {
                                    continuation.yield(.chunk(text: text))
                                    nGenerationTokens += 1
                                }
                            }
                        }
                    }
                    let info = try conversation.getBenchmarkInfo()
                    continuation.yield(
                        .complete(
                            metrics: TextAIMetrics(
                                nPromptTokens: info.lastPrefillTokenCount,
                                nGenerationTokens: info.lastDecodeTokenCount
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
