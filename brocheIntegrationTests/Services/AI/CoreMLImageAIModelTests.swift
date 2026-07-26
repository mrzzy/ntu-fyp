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
            for try await _ in try await model.edit(
                image: Data(), prompt: "a cat", options: ImageAIOptions()
            ) {}
        }
    }

    @Test("Load throws invalidModelID for malformed model ID")
    func loadThrowsInvalidModelID() async {
        let model = CoreMLImageAIModel(modelID: "no-slash-model-id")

        await #expect(throws: CoreMLImageAIError.invalidModelID(modelID: "no-slash-model-id")) {
            try await model.load()
        }
    }

    @Test("Load and Edit returns non-empty image data")
    func loadAndEditReturnsImage() async throws {
        let model = CoreMLImageAIModel(modelID: testModelID, patterns: testPatterns, path: testPath)

        if let resourcePath = Bundle.main.resourcePath {
            try print(
                FileManager.default.contentsOfDirectory(
                    atPath: resourcePath
                )
            )
        }

        guard
            let url = Bundle.main.url(
                forResource: "apple_sketch", withExtension: "png"
            )
        else {
            throw URLError(.fileDoesNotExist)
        }

        try await model.load()

        let steps = 30
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        var imageData: Data?
        var progressCount = 0
        let stream = try model.edit(
            image: Data(contentsOf: url),
            prompt: "Rerender in a style of a watercolor",
            options: ImageAIOptions(
                steps: steps,
                guidance: 7.5,
                strength: 0.8,
                seed: 42
            )
        )

        for try await output in stream {
            switch output {
            case .progress(let step):
                progressCount += 1
                #expect(step <= steps)
                print("Generating image: step \(step)/\(steps)")
            case .image(let data):
                imageData = data
            }
        }

        #expect(progressCount > 0)
        #expect(imageData != nil)
        #expect(try !#require(imageData?.isEmpty))

        // write output to disk for visual verification
        let outputURL = documentsDir.appendingPathComponent(
            "CoreMLImageAIModelTests_loadAndEditReturnsImage.5.png"
        )
        try imageData?.write(to: outputURL)
        print("Saved generated image :", outputURL.path)
    }
}
