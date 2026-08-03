//
//  MLXVisualAIModelswift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-28
//

import CoreImage
import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLMCommon
import MLXVLM
import Tokenizers

final class MLXVisualAIModel: VisualAIModel {
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
        prompt: String,
        images: [Data],
        options: VisualAIOptions
    ) -> AsyncThrowingStream<VisualAIOutput, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let model else {
                        throw VisualAIError.modelNotLoaded
                    }

                    let chat = ChatSession(model)
                    chat.generateParameters = GenerateParameters(
                        maxTokens: maxTokens,
                        temperature: options.temperature,
                        topP: options.topP
                    )
                    if options.seed != 0 {
                        chat.generateParameters.seed = UInt64(options.seed)
                    }

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
