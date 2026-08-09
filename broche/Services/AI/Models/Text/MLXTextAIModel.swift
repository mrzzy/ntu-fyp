//
//  MLXTextAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-20.
//

import Foundation
import MLXHuggingFace
import MLXLMCommon
import MLXLLM
import HuggingFace
import Tokenizers

enum LLMError: Error, LocalizedError, Equatable {
    case modelNotLoaded
    case invalidModelPath(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "Model has not been loaded. Call load() first."
        case .invalidModelPath(let path):
            "Invalid model path: \(path)"
        }
    }
}

final class MLXTextAIModel: TextAIModel {
    let modelID: String
    let maxTokens: Int
    var model: ModelContext?

    init(modelID: String, maxTokens: Int = 2048) {
        self.modelID = modelID
        self.maxTokens = maxTokens
    }

    func load() async throws {
        model = try await loadModel(
            from: #hubDownloader(),
            using: #huggingFaceTokenizerLoader(),
            id: modelID
        )
    }

    func generate(
        messages: [Message],
        options: TextAIOptions
    ) -> AsyncThrowingStream<TextAIOutput, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let model else {
                        throw LLMError.modelNotLoaded
                    }

                    let chat = ChatSession(model, tools: options.tools)
                    chat.generateParameters = GenerateParameters(
                        maxTokens: maxTokens,
                        temperature: options.temperature,
                        topP: options.topP,
                        topK: options.topK,
                        seed: UInt64(options.seed)
                    )

                    let chatMessages = messages.map { msg -> Chat.Message in
                        switch msg.user {
                        case .system:
                            return .system(msg.text)
                        case .user:
                            return .user(msg.text)
                        case .ai:
                            return .assistant(msg.text)
                        case .tool:
                            return .tool(msg.text)
                        }
                    }

                    for try await generation in chat.streamDetails(to: chatMessages) {
                        switch generation {
                        case .chunk(let text):
                            continuation.yield(.chunk(text: text))
                        case .toolCall(let call):
                            let args = call.function.arguments.mapValues { $0.anyValue }
                            let argsJSON = String(
                                data: try JSONSerialization.data(
                                    withJSONObject: args, options: [.sortedKeys]
                                ),
                                encoding: .utf8
                            )!
                            continuation.yield(
                                .call(call: AIToolCall(name: call.function.name, argsJSON: argsJSON))
                            )
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
