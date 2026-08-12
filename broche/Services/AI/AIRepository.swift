//
//  AIRepository.swift
//  broche
//  Created by Zhu Zhanyan on 2026-08-10
//

/// Caches and manages access the AI models used in the app.
class AIRepository {
    let textModel: TextAIModel
    let imageModel: ImageAIModel
    let visualModel: VisualAIModel
    private(set) var isLoaded = false

    /// Shared singleton instance of AIRepository
    static let shared: AIRepository = .init(DefaultAIModelFactory.shared)

    init(_ modelFactory: AIModelFactory) {
        textModel = modelFactory.makeTextModel()
        visualModel = modelFactory.makeVisualModel()
        imageModel = modelFactory.makeImageModel()
    }

    /// Ensures that all AI models are loaded asynchronously.
    /// If the models are already loaded, this function returns immediately.
    func load() async throws {
        // Check if models are already loaded to avoid redundant loading
        if isLoaded {
            return
        }
        // loads models asynchronously
        async let textLoad = textModel.load()
        async let visualLoad = visualModel.load()
        async let imageLoad = imageModel.load()
        _ = try await (textLoad, visualLoad, imageLoad)
        isLoaded = true
    }
}
