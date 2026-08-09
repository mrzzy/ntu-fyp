import Foundation
import Testing

@testable import broche

struct MockImageAIModel: ImageAIModel {
    let modelID: String = "mock-image-model"

    func load() async throws {}

    func edit(
        image: Data,
        prompt: String,
        options: ImageAIOptions
    ) -> AsyncThrowingStream<ImageAIOutput, Error> {
        AsyncThrowingStream { continuation in
            guard let url = Bundle.allBundles.first(where: { bundle in
                bundle.url(forResource: "apple_ai", withExtension: "png") != nil
            })?.url(forResource: "apple_ai", withExtension: "png") else {
                continuation.finish(throwing: NSError(
                    domain: "MockImageAIModel",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "apple_ai.png not found in test bundle"]
                ))
                return
            }
            guard let data = try? Data(contentsOf: url) else {
                continuation.finish(throwing: NSError(
                    domain: "MockImageAIModel",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to load apple_ai.png"]
                ))
                return
            }

            continuation.yield(.progress(step: 1))
            continuation.yield(
                .image(
                    image: data,
                    metrics: ImageAIMetrics(nSamples: 1, nSteps: 1)
                )
            )
            continuation.finish()
        }
    }
}
