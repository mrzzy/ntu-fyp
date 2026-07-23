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
            "Model has not been loaded. Call load(:) first."
        case .invalidModelPath(let path):
            "Invalid model path: \(path)"
        }
    }
}

final class MLXTextAIModel: TextAIModel {
    let modelID: String
    let maxTokens: Int

    private var chat: ChatSession?

    init(modelID: String, maxTokens: Int = 2048) {
        self.modelID = modelID
        self.maxTokens = maxTokens
    }

    func load() async throws {
        let model = try await LLMModelFactory.shared.loadContainer(
            from: #hubDownloader(),
            using: #huggingFaceTokenizerLoader(),
            configuration: ModelConfiguration(id: modelID)
        )

        chat = ChatSession(model)
    }

    func generate(
        prompt: String,
        options: TextAIOptions
    ) async throws -> AsyncThrowingStream<TextAIOutput, Error> {
        guard let chat else {
            throw LLMError.modelNotLoaded
        }

        chat.generateParameters = GenerateParameters(
            maxTokens: maxTokens,
            temperature: options.temperature,
            topP: options.topP,
            topK: options.topK,
            seed: UInt64(options.seed),
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = chat.streamDetails(to: prompt)
                    for try await generation in stream {
                        switch generation {
                        case .chunk(let text):
                            continuation.yield(.chunk(text: text))
                        case .toolCall(let call):
                            print("Tool call: \(call)")
                        // completion info at the end of generation
                        case .info(let info):
                            let metrics = TextAIMetrics(
                                nPromptTokens: info.promptTokenCount,
                                nGenerationTokens: info.generationTokenCount
                            )
                            continuation.yield(.complete(metrics: metrics))
                            continuation.finish()
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
