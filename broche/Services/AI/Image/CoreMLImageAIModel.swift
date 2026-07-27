//
//  CoreMLImageAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-24.
//

import CoreImage
import CoreML
import Foundation
import HuggingFace
import ImageIO
import StableDiffusion

enum CoreMLImageAIError: Error, Equatable {
    case pipelineNotLoaded
    case imageLoadFailed
    case invalidModelID(modelID: String)
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .pipelineNotLoaded:
            "Pipeline has not been loaded. Call load() first."
        case .imageLoadFailed:
            "Input image data could not be loaded."
        case let .invalidModelID(id):
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
    let inputSize: CGSize
    let controlNets: [String]

    private var pipeline: StableDiffusionPipelineProtocol?

    init(
        modelID: String,
        // pattern is necessary to ensure only files entries are downloaded
        // swift-huggingface fails to download directory entries
        patterns: [String] = ["*.*"],
        path: String = "",
        inputSize: CGSize = CGSize(width: 512, height: 512),
        controlNets: [String] = []
    ) {
        self.modelID = modelID
        self.patterns = patterns
        self.path = path
        self.inputSize = inputSize
        self.controlNets = controlNets
    }

    func load() async throws {
        guard let repoID = Repo.ID(rawValue: modelID) else {
            throw CoreMLImageAIError.invalidModelID(modelID: modelID)
        }

        // download model from huggingface
        let client = HubClient.default
        let modelPath = try await client.downloadSnapshot(
            of: repoID,
            kind: .model
        )

        let configuration = MLModelConfiguration()

        // load the model with retries to overcome transient failures
        let maxRetries = 3
        for nRetry in 1 ... maxRetries {
            do {
                let pipeline = try StableDiffusionPipeline(
                    resourcesAt: modelPath.appending(component: path),
                    controlNet: controlNets,
                    configuration: configuration,
                    reduceMemory: false
                )
                try pipeline.loadResources()
                self.pipeline = pipeline
                break
            } catch {
                print("Model load failed (attempt \(nRetry)/\(maxRetries)),: \(error)")
                if nRetry == maxRetries {
                    throw error
                }
            }
        }
    }

    func edit(image: Data, prompt: String, options: ImageAIOptions) -> AsyncThrowingStream<
        ImageAIOutput, Error
    > {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let pipeline else {
                        throw CoreMLImageAIError.pipelineNotLoaded
                    }

                    guard let cgImage = cgimageFromData(image) else {
                        throw CoreMLImageAIError.imageLoadFailed
                    }

                    let originalSize = CGSize(width: cgImage.width, height: cgImage.height)

                    var config = StableDiffusionPipeline.Configuration(prompt: prompt)
                    config.stepCount = options.steps
                    config.seed = options.seed
                    config.guidanceScale = options.guidance
                    config.controlNetInputs = [resize(cgImage, to: inputSize)!]

                    let images = try pipeline.generateImages(configuration: config) { p in
                        continuation.yield(.progress(step: p.step))
                        return !Task.isCancelled
                    }
                    guard let outputImage = images.first, let cgOutput = outputImage else {
                        throw CoreMLImageAIError.generationFailed
                    }

                    // stretch output back to original aspect ratio
                    let restoredOutput = resize(cgOutput, to: originalSize)!

                    guard let data = Self.pngData(from: restoredOutput) else {
                        throw CoreMLImageAIError.generationFailed
                    }

                    continuation.yield(.image(data))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Resizes the image to the target size without preserving aspect ratio.
    func resize(
        _ cgImage: CGImage,
        to size: CGSize,
        context: CIContext = CIContext()
    ) -> CGImage? {
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        let resized = ciImage.transformed(
            by: CGAffineTransform(scaleX: scaleX, y: scaleY)
        )
        return context.createCGImage(
            resized,
            from: CGRect(origin: .zero, size: size)
        )
    }

    func cgimageFromData(_ data: Data) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
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
