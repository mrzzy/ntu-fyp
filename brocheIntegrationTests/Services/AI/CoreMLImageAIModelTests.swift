//
//  CoreMLImageAIModelTests.swift
//  brocheIntegrationTests
//
//  Created by Zhu Zhanyan on 2026-07-24.
//

import Foundation
import Testing

@testable import broche

private let testModelID = "apple/coreml-stable-diffusion-2-1-base-palettized"
private let testPath = "split_einsum_v2/compiled"
private let testPatterns = [
    "bin",
    "json",
    "mil",
    "txt",
].map {
    "\(testPath)/*.\($0)"
}

@Suite("CoreMLImageAIModel tests")
@MainActor
struct CoreMLImageAIModelTests {
    @Test("Edit throws pipelineNotLoaded when model is not loaded")
    func editThrowsPipelineNotLoadedWhenNotLoaded() async {
        let model = CoreMLImageAIModel(modelID: testModelID)

        await #expect(throws: CoreMLImageAIError.self) {
            try await model.edit(image: Data(), prompt: "a cat", options: ImageAIOptions())
        }
    }

    @Test("Load throws invalidModelID for malformed model ID")
    func loadThrowsInvalidModelID() async {
        let model = CoreMLImageAIModel(modelID: "no-slash-model-id")

        await #expect(throws: CoreMLImageAIError.invalidModelID(modelID: "no-slash-model-id")) {
            try await model.load()
        }
    }

    @Test("Load succeeds with valid model ID")
    func loadSucceeds() async throws {
        let model = CoreMLImageAIModel(modelID: testModelID, patterns: testPatterns, path: testPath)
        // M2 iPad: takes about 82s
        try await model.load()
    }

    @Test("Load and Edit returns non-empty image data")
    func loadAndEditReturnsImage() async throws {
        let model = CoreMLImageAIModel(modelID: testModelID, patterns: testPatterns, path: testPath)

        try await model.load()

        let result = try await model.edit(
            image: Data(),
            prompt: "a watercolor painting of a cat",
            options: ImageAIOptions(steps: 30)
        )

        #expect(!result.isEmpty)
    }
}
