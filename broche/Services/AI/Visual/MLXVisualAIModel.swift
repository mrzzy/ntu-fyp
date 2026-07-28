//
//  MLXVisualAIModelswift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-28
//

import CoreImage
import Foundation
import MLXHuggingFace
import MLXLMCommon
import MLXVLM
import Tokenizers
import HuggingFace

final class MLXVisualAIModel: VisualAIModel {
    let modelID: String
    let maxTokens: Int
    private var chat: ChatSession?
    init(modelID: String, maxTokens: Int = 2048) {
        self.modelID = modelID
        self.maxTokens = maxTokens
    }

    func load() async throws {
        let model = try await loadModel(
            from: #hubDownloader(),
            using: #huggingFaceTokenizerLoader(),
            id: modelID
        )
        chat = ChatSession(model)
    }

    func generate(
        prompt: String,
        images: [Data],
        options: VisualAIOptions
    ) -> AsyncThrowingStream<VisualAIOutput, Error> {
        guard let chat else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: VisualAIError.modelNotLoaded)
            }
        }

        chat.generateParameters = GenerateParameters(
            maxTokens: maxTokens,
            temperature: options.temperature,
            topP: options.topP
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // convert input images to core image
                    let imageInputs = try images.compactMap { data in
                        guard let ciImage = CIImage(data: data) else {
                            throw VisualAIError.imageDecodingFailed
                        }
                        return UserInput.Image.ciImage(ciImage)
                    }
                    for try await out in chat.streamDetails(to: prompt, images: imageInputs) {
                        switch out {
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
