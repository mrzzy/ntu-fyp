//
//  OpenRouterTextAIModel.swift
//  broche
//

import CloudKit
import Foundation
import OpenAI

/// Errors that can occur during OpenRouter text generation.
enum OpenRouterTextAIError: Swift.Error, LocalizedError, Equatable {
    case modelNotLoaded
    case tokenNotFound

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "Model has not been loaded. Call load() first."
        case .tokenNotFound:
            "OpenRouter API token not found in CloudKit."
        }
    }
}

/// A remote text generation model backed by OpenRouter's chat completions API.
///
/// Uses the [MacPaw/OpenAI](https://github.com/MacPaw/OpenAI) Swift SDK configured
/// to route requests through ``OpenRouter/openrouter.ai``.
/// The API token is stored in CloudKit under the `openrouterToken` record.
final class OpenRouterTextAIModel: TextAIModel {
    /// The OpenRouter model identifier (e.g. `"openai/gpt-4o-mini"`).
    let modelID: String
    private var client: OpenAI?

    /// - Parameter modelID: An OpenRouter model slug.
    init(modelID: String = "qwen/qwen3-30b-a3b-instruct-2507") {
        self.modelID = modelID
    }

    /// Fetches the OpenRouter API token from CloudKit and initialises the ``OpenAI`` client.
    ///
    /// - Throws: ``OpenRouterTextAIError/tokenNotFound`` when the token record is missing or empty.
    func load() async throws {
        let recordID = CKRecord.ID(recordName: "openrouterToken")
        let record = try await CKContainer(identifier: "iCloud.inc.cloudKitTest")
            .publicCloudDatabase.record(for: recordID)
        guard let token = record["token"] as? String, !token.isEmpty else {
            throw OpenRouterTextAIError.tokenNotFound
        }
        client = OpenAI(
            configuration: OpenAI.Configuration(
                token: token,
                host: "openrouter.ai",
                basePath: "/api/v1"
            )
        )
    }

    /// Streams a text completion for the given conversation via OpenRouter.
    ///
    /// Text chunks, accumulated tool calls, and final usage metrics are yielded
    /// through the returned ``AsyncThrowingStream``.
    ///
    /// - Parameters:
    ///   - messages: The conversation history to send to the model.
    ///   - options: Sampling parameters (temperature, top-p, seed) and optional tool specifications.
    /// - Returns: A stream of ``TextAIOutput`` values.
    /// - Throws: ``OpenRouterTextAIError/modelNotLoaded`` if ``load()`` has not been called,
    ///           or any network/API error from the OpenRouter service.
    func generate(
        messages: [Message],
        options: TextAIOptions
    ) -> AsyncThrowingStream<TextAIOutput, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let client else {
                        throw OpenRouterTextAIError.modelNotLoaded
                    }

                    // convert our Message type to OpenRouter's ChatCompletionMessageParam
                    typealias MessageParam = ChatQuery.ChatCompletionMessageParam

                    // convert our tool specifications to OpenRouter's ChatCompletionToolParam
                    let query = ChatQuery(
                        messages: OpenAIAdaptors.toChatMessages(from: messages),
                        model: modelID,
                        seed: options.seed,
                        temperature: Double(options.temperature),
                        tools: OpenAIAdaptors.toToolParams(from: options.tools),
                        topP: Double(options.topP),
                        stream: true
                    )

                    let stream: AsyncThrowingStream<ChatStreamResult, Error> =
                        client.chatsStream(query: query)

                    var toolCallAccumulator: [Int: (id: String, name: String, args: String)] = [:]
                    var promptTokens = 0
                    var completionTokens = 0

                    for try await chunk in stream {
                        if let usage = chunk.usage {
                            promptTokens = usage.promptTokens
                            completionTokens = usage.completionTokens
                        }

                        if let choice = chunk.choices.first {
                            if let content = choice.delta.content, !content.isEmpty {
                                continuation.yield(.chunk(text: content))
                            }

                            if let toolCalls = choice.delta.toolCalls {
                                for tc in toolCalls {
                                    let idx = tc.index
                                    if toolCallAccumulator[idx] == nil {
                                        toolCallAccumulator[idx] = (
                                            id: tc.id ?? "",
                                            name: tc.function?.name ?? "",
                                            args: ""
                                        )
                                    }
                                    if let args = tc.function?.arguments {
                                        toolCallAccumulator[idx]?.args += args
                                    }
                                }
                            }

                            if let finishReason = choice.finishReason,
                                finishReason == .toolCalls || finishReason == .stop
                            {
                                for idx in toolCallAccumulator.keys.sorted() {
                                    if let tc = toolCallAccumulator[idx] {
                                        continuation.yield(
                                            .call(
                                                call: AIToolCall(
                                                    name: tc.name,
                                                    argsJSON: tc.args
                                                )
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }

                    continuation.yield(
                        .complete(
                            metrics: TextAIMetrics(
                                nPromptTokens: promptTokens,
                                nGenerationTokens: completionTokens
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
