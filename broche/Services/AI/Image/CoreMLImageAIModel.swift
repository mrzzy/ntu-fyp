//
//  CoreMLImageAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-24.
//

import CoreML
import Foundation
import HuggingFace
import ImageIO
import StableDiffusion

enum CoreMLImageAIError: Error, Equatable {
    case pipelineNotLoaded
    case invalidModelID(modelID: String)
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .pipelineNotLoaded:
            "Pipeline has not been loaded. Call load() first."
        case .invalidModelID(let id):
            "Model ID '\(id)' is not a valid HuggingFace repository identifier (expected 'namespace/name')."
        case .generationFailed:
            "Image generation failed."
        }
    }
}

final class CoreMLImageAIModel: ImageAIModel {
    let modelID: String
    let patterns: [String]
    let path: String

    private var pipeline: (any StableDiffusionPipelineProtocol)?

    init(
        modelID: String,
        patterns: [String] = [],
        path: String = ""
    ) {
        self.modelID = modelID
        self.patterns = patterns
        self.path = path
    }

    func load() async throws {
        guard let repoID = Repo.ID(rawValue: modelID) else {
            throw CoreMLImageAIError.invalidModelID(modelID: modelID)
        }

        // download model from huggingface
        let client = HubClient.default
        let modelPath = try await client.downloadSnapshot(
            of: repoID,
            kind: .model,
            matching: patterns
        )

        let configuration = MLModelConfiguration()
        let pipeline = try StableDiffusionPipeline(
            resourcesAt: modelPath.appending(component: path),
            controlNet: [],
            configuration: configuration,
            reduceMemory: false
        )
        try pipeline.loadResources()
        self.pipeline = pipeline
    }

    func edit(image _: Data, prompt: String, options: ImageAIOptions) async throws -> Data {
        guard let pipeline else {
            throw CoreMLImageAIError.pipelineNotLoaded
        }

        var config = StableDiffusionPipeline.Configuration(prompt: prompt)
        config.stepCount = options.steps
        config.seed = options.seed
        config.strength = options.strength
        config.guidanceScale = options.guidance

        let images = try pipeline.generateImages(configuration: config) {
            p in
            print(
                "Progress: \(p.step)/\(p.stepCount) \(Float(p.step) / Float(p.stepCount) * 100.0)%")
            return true
        }
        guard let outputImage = images.first, let cgOutput = outputImage else {
            throw CoreMLImageAIError.generationFailed
        }

        guard let data = Self.pngData(from: cgOutput) else {
            throw CoreMLImageAIError.generationFailed
        }

        return data
    }

    private static func pngData(from cgImage: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                mutableData, "public.png" as CFString, 1, nil
            )
        else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
