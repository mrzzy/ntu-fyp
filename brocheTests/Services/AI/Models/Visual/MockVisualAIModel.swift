import Foundation
import Testing

@testable import broche

struct MockVisualAIModel: VisualAIModel {
    let modelID: String = "mock-visual-model"

    private let mockCaption: String

    init(
        mockCaption: String =
            "A sketch of an apple sliced on a plate with a cup at the side."
    ) {
        self.mockCaption = mockCaption
    }

    func load() async throws {}

    func generate(
        prompt: String,
        images: [Data],
        options: VisualAIOptions
    ) -> AsyncThrowingStream<VisualAIOutput, Error> {
        let caption = mockCaption
        return AsyncThrowingStream { continuation in
            continuation.yield(.chunk(text: caption))
            continuation.yield(
                .complete(
                    metrics: TextAIMetrics(
                        nPromptTokens: 10,
                        nGenerationTokens: caption.count
                    )
                )
            )
            continuation.finish()
        }
    }
}
