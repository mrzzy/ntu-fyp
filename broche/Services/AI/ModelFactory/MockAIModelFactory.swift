import Foundation

struct MockAIModelFactory: AIModelFactory {
    let mockTextResponse: String
    let mockTextToolCalls: [AIToolCall]
    let mockVisualCaption: String

    var secrets: Secrets

    static let shared = MockAIModelFactory()

    init(
        mockTextResponse: String = "This is a mock text response.",
        mockTextToolCalls: [AIToolCall] = [],
        mockVisualCaption: String =
            "A sketch of an apple sliced on a plate with a cup at the side.",
        secrets: Secrets = StaticSecrets(openRouter: "", replicate: "")
    ) {
        self.mockTextResponse = mockTextResponse
        self.mockTextToolCalls = mockTextToolCalls
        self.mockVisualCaption = mockVisualCaption
        self.secrets = secrets
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
