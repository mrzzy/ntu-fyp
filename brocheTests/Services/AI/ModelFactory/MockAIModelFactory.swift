import Foundation
import Testing

@testable import broche

struct MockAIModelFactory: AIModelFactory {
    let mockTextResponse: String
    let mockTextToolCalls: [AIToolCall]
    let mockVisualCaption: String

    init(
        mockTextResponse: String = "This is a mock text response.",
        mockTextToolCalls: [AIToolCall] = [],
        mockVisualCaption: String =
            "A sketch of an apple sliced on a plate with a cup at the side."
    ) {
        self.mockTextResponse = mockTextResponse
        self.mockTextToolCalls = mockTextToolCalls
        self.mockVisualCaption = mockVisualCaption
    }

    func makeTextModel() -> TextAIModel {
        MockTextAIModel(
            mockResponse: mockTextResponse,
            mockToolCalls: mockTextToolCalls
        )
    }

    func makeVisualModel() -> VisualAIModel {
        MockVisualAIModel(mockCaption: mockVisualCaption)
    }

    func makeImageModel() -> ImageAIModel {
        MockImageAIModel()
    }
}
