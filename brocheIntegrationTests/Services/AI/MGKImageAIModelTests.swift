//
//  MGKImageAIModelTests.swift
//  brocheIntegrationTests
//
//  Created by Zhu Zhanyan on 2026-07-27.
//

import Foundation
import Testing

@testable import broche

private let testModelID = "flux_2_klein_base_4b_q6p.ckpt"

@Suite("MGKImageAIModel tests")
@MainActor
struct MGKImageAIModelTests {
    @Test("Edit throws pipelineNotLoaded when model is not loaded")
    func editThrowsPipelineNotLoadedWhenNotLoaded() async {
        let model = MGKImageAIModel(modelID: testModelID)

        await #expect(throws: MGKImageAIError.self) {
            for try await _ in try await model.edit(
                image: Data(), prompt: "a cat", options: ImageAIOptions()
            ) {}
        }
    }

    @Test("Load throws error for unresolved model ID")
    func loadThrowsForUnresolvedModelID() async {
        let model = MGKImageAIModel(modelID: "nonexistent-model-xyz")

        await #expect(throws: Error.self) {
            try await model.load()
        }
    }

    @Test("Load and Edit returns non-empty image data")
    func loadAndEditReturnsImage() async throws {
        guard
            let url = Bundle.main.url(
                forResource: "apple_sketch", withExtension: "png"
            )
        else {
            throw URLError(.fileDoesNotExist)
        }

        let model = MGKImageAIModel(
            modelID: testModelID,
            controlNets: ["controlnet_scribble_1.x_v1.1_f16.ckpt"]
        )

        try await model.load()

        let sketchData = try Data(contentsOf: url)
        let prompt =
            "Render apple, plate & cup in a watercolor painting, transparent washes, pigment granulation, color bleeding, wet-on-wet technique,  loose expressive brushstrokes, soft edges, subtle gradients, natural pigments"

        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
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
            case .progress(let step):
                progressCount += 1
                #expect(step <= steps)
                print("  step \(step)/\(steps)")
            case .image(let data):
                imageData = data
            }
        }

        #expect(progressCount > 0)
        #expect(imageData != nil)
        #expect(try !#require(imageData?.isEmpty))

        let outputURL = documentsDir.appendingPathComponent(
            "MGKImageAIModelTests_loadAndEditReturnsImage.png")
        try imageData?.write(to: outputURL)
        print("  Saved: \(outputURL.path)")
    }
}
