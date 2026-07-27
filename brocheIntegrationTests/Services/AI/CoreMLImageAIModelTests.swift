//
//  CoreMLImageAIModelTests.swift
//  brocheIntegrationTests
//
//  Created by Zhu Zhanyan on 2026-07-24.
//

@testable import broche
import Foundation
import Testing

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

        let sketchData = try Data(contentsOf: url)
        let prompt =
            "Render apple, plate & cup in a watercolor painting, transparent washes, pigment granulation, color bleeding, wet-on-wet technique,  loose expressive brushstrokes, soft edges, subtle gradients, natural pigments"

        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let outputDir = documentsDir.appendingPathComponent(
            "CoreMLImageAIModelTests_sweep"
        )
        try FileManager.default.createDirectory(
            at: outputDir, withIntermediateDirectories: true
        )

        let steps = 50
        var imageData: Data?
        var progressCount = 0
        let stream = model.edit(
            image: sketchData,
            prompt: prompt,
            options: ImageAIOptions(
                steps: steps,
                guidance: 3.0,
                seed: 42
            )
        )

        for try await output in stream {
            switch output {
            case let .progress(step):
                progressCount += 1
                #expect(step <= steps)
                print("  step \(step)/\(steps)")
            case let .image(data):
                imageData = data
            }
        }

        #expect(progressCount > 0)
        #expect(imageData != nil)
        #expect(try !#require(imageData?.isEmpty))

        let outputURL = outputDir.appendingPathComponent("CoreMLImageAIModelTests_loadAndEditReturnsImage.png")
        try imageData?.write(to: outputURL)
        print("  Saved: \(outputURL.path)")
    }
}
