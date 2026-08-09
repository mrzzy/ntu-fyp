import Foundation
import Testing

@testable import broche

class MockTextAIModel: TextAIModel {
    let modelID: String = "mock-text-model"

    private let mockResponse: String
    private var mockToolCalls: [AIToolCall]

    init(
        mockResponse: String = "This is a mock text response.",
        mockToolCalls: [AIToolCall] = []
    ) {
        self.mockResponse = mockResponse
        self.mockToolCalls = mockToolCalls
    }

    func load() async throws {}

    func generate(
        messages _: [Message],
        options _: TextAIOptions
    ) -> AsyncThrowingStream<TextAIOutput, Error> {
        let response = mockResponse
        return AsyncThrowingStream { continuation in
            continuation.yield(.chunk(text: "Generating tool calls: \(mockToolCalls)"))
            for call in mockToolCalls {
                continuation.yield(.call(call: call))
            }
            // empty tool calls so that the TextAIModel only generates them once
            mockToolCalls = []

            continuation.yield(.chunk(text: response))
            continuation.yield(
                .complete(
                    metrics: TextAIMetrics(
                        nPromptTokens: 10,
                        nGenerationTokens: response.count
                    )
                )
            )
            continuation.finish()
        }
    }
}
