//
//  OpenRouterVisualAIModel.swift
//  broche
//

import Foundation
import OpenAI
import UIKit

/// Errors that can occur during OpenRouter visual text generation.
enum OpenRouterVisualAIError: Swift.Error, LocalizedError, Equatable {
    case modelNotLoaded
    case imageDataInvalid

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "Model has not been loaded. Call load() first."
        case .imageDataInvalid:
            "Image data is invalid and could not be decoded."
        }
    }
}

/// A remote visual language model (VLM) backed by OpenRouter's chat completions API.
///
/// Uses the [MacPaw/OpenAI](https://github.com/MacPaw/OpenAI) Swift SDK configured
/// to route requests through OpenRouter. Images are base64-encoded and sent as
/// `image_url` content parts alongside the text prompt.
final class OpenRouterVisualAIModel: VisualAIModel {
    /// Maximum dimension (width or height) of an image sent to the API.
    private static let maxImageDimension: CGFloat = 512

    /// The OpenRouter model identifier (e.g. `"openai/gpt-4o-mini"`).
    let modelID: String
    let secrets: Secrets
    private var client: OpenAI?

    /// - Parameter modelID: An OpenRouter model slug that supports vision.
    init(modelID: String = "openai/gpt-5-nano", secrets: Secrets) {
        self.modelID = modelID
        self.secrets = secrets
    }

    func load() async throws {
        client = try OpenAI(
            configuration: OpenAI.Configuration(
                token: await secrets.openRouterToken(),
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
                        // pad image into square to avoid cropping on model side clipping contents of image.
                        guard let uiImage = UIImage(data: imageData) else {
                            throw OpenRouterVisualAIError.imageDataInvalid
                        }
                        let base64 = padSquare(uiImage).pngData()!.base64EncodedString()
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
                                                    id: tc.id,
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

    /// Scales `image` down so its longest side fits `maxSize` (preserving aspect
    /// ratio), then pads it into a square of white `backgroundColor` so it isn't
    /// cropped by model-side preprocessing.
    private func padSquare(
        _ image: UIImage,
        maxSize: CGFloat = OpenRouterVisualAIModel.maxImageDimension,
        backgroundColor: UIColor = .white
    ) -> UIImage {
        let maxDimension = max(image.size.width, image.size.height)
        let scale = maxDimension > 0 ? min(1, maxSize / maxDimension) : 1
        let scaledSize = CGSize(
            width: (image.size.width * scale).rounded(.down),
            height: (image.size.height * scale).rounded(.down)
        )
        let side = max(scaledSize.width, scaledSize.height)
        let size = CGSize(width: side, height: side)

        let origin = CGPoint(
            x: (side - scaledSize.width) / 2,
            y: (side - scaledSize.height) / 2
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            backgroundColor.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}
