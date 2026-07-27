//
//  CoreMLImageAIModelTests.swift
//  brocheIntegrationTests
//
//  Created by Zhu Zhanyan on 2026-07-24.
//

import Foundation
import Testing

@testable import broche

private let testModelID = "mrzzy/coreml-sd-v1-5-controlnet"

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
        // load starting sketch
        guard
            let url = Bundle.main.url(
                forResource: "apple_sketch", withExtension: "png"
            )
        else {
            throw URLError(.fileDoesNotExist)
        }

        // load image model
        let model = CoreMLImageAIModel(
            modelID: testModelID,
            controlNets: ["LllyasvielSdControlnetScribble"]
        )

        try await model.load()

        let steps = 50
        var imageData: Data?
        var progressCount = 0
        let stream = try model.edit(
            image: Data(contentsOf: url),
            prompt:
                "lines form shapes that should be colored in, watercolor painting, transparent washes, pigment granulation, color bleeding, wet-on-wet technique,  loose expressive brushstrokes, soft edges, subtle gradients, natural pigments",
            options: ImageAIOptions(
                steps: steps,
                guidance: 7.5,
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
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let outputURL = documentsDir.appendingPathComponent(
            "CoreMLImageAIModelTests_loadAndEditReturnsImage.png"
        )
        try imageData?.write(to: outputURL)
        print("Saved generated image :", outputURL.path)
    }
}
