//
//  MLXTextAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-20.
//

import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

enum LLMError: Error, LocalizedError {
    case modelNotLoaded
    case invalidModelPath(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "Model has not been loaded. Call load(modelID:) first."
        case .invalidModelPath(let path):
            "Invalid model path: \(path)"
        }
    }
}

final class MLXTextAIModel: TextAIModel {
    private var chat: ChatSession?

    func load(modelID: String) async throws {
        let model = try await LLMModelFactory.shared.loadContainer(
            from: #hubDownloader(),
            using: #huggingFaceTokenizerLoader(),
            configuration: ModelConfiguration(id: modelID)
        )

        chat = ChatSession(model)
    }

    func generate(
        prompt: String,
        options: TextGenerationOptions
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let chat else {
            throw LLMError.modelNotLoaded
        }

        chat.generateParameters = GenerateParameters(
            maxTokens: options.maxTokens,
            temperature: options.temperature
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = chat.streamResponse(to: prompt)
                    for try await chunk in response {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
