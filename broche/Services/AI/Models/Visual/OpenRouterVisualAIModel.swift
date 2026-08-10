//
//  OpenRouterVisualAIModel.swift
//  broche
//

import CloudKit
import Foundation
import OpenAI

/// Errors that can occur during OpenRouter visual text generation.
enum OpenRouterVisualAIError: Swift.Error, LocalizedError, Equatable {
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

/// A remote visual language model (VLM) backed by OpenRouter's chat completions API.
///
/// Uses the [MacPaw/OpenAI](https://github.com/MacPaw/OpenAI) Swift SDK configured
/// to route requests through OpenRouter. Images are base64-encoded and sent as
/// `image_url` content parts alongside the text prompt. The API token is stored in
/// CloudKit under the `openrouterToken` record.
final class OpenRouterVisualAIModel: VisualAIModel {
    /// The OpenRouter model identifier (e.g. `"openai/gpt-4o-mini"`).
    let modelID: String
    private var client: OpenAI?

    /// - Parameter modelID: An OpenRouter model slug that supports vision.
    init(modelID: String = "openai/gpt-5-nano") {
        self.modelID = modelID
    }

    /// Fetches the OpenRouter API token from CloudKit and initialises the ``OpenAI`` client.
    ///
    /// - Throws: ``OpenRouterVisualAIError/tokenNotFound`` when the token record is missing or empty.
    func load() async throws {
        let recordID = CKRecord.ID(recordName: "openrouterToken")
        let record = try await CKContainer(identifier: "iCloud.inc.cloudKitTest")
            .publicCloudDatabase.record(for: recordID)
        guard let token = record["token"] as? String, !token.isEmpty else {
            throw OpenRouterVisualAIError.tokenNotFound
        }
        client = OpenAI(
            configuration: OpenAI.Configuration(
                token: token,
                host: "openrouter.ai",
                basePath: "/api/v1"
            )
        )
    }

    /// Streams a visual text completion for the given prompt and images via OpenRouter.
    ///
    /// The prompt and images are combined into a single multi-part user message.
    /// Text chunks, accumulated tool calls, and final usage metrics are yielded
    /// through the returned ``AsyncThrowingStream``.
    ///
    /// - Parameters:
    ///   - prompt: The text prompt to send alongside the images.
    ///   - images: PNG-encoded image data to include as visual context.
    ///   - options: Sampling parameters (temperature, top-p, seed) and optional tool specifications.
    /// - Returns: A stream of ``VisualAIOutput`` values.
    /// - Throws: ``OpenRouterVisualAIError/modelNotLoaded`` if ``load()`` has not been called,
    ///           or any network/API error from the OpenRouter service.
    func generate(
        prompt: String,
        images: [Data],
        options: VisualAIOptions
    ) -> AsyncThrowingStream<VisualAIOutput, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let client else {
                        throw OpenRouterVisualAIError.modelNotLoaded
                    }

                    typealias MessageParam = ChatQuery.ChatCompletionMessageParam

                    var contentParts: [MessageParam.UserMessageParam.Content.ContentPart] =
                        [.text(.init(text: prompt))]

                    for imageData in images {
                        let base64 = imageData.base64EncodedString()
                        contentParts.append(
                            .image(
                                .init(
                                    imageUrl: .init(
                                        url: "data:image/png;base64,\(base64)",
                                        detail: .auto
                                    )
                                )
                            )
                        )
                    }

                    let userMessage = MessageParam.user(
                        .init(content: .contentParts(contentParts))
                    )

                    let query = ChatQuery(
                        messages: [userMessage],
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
