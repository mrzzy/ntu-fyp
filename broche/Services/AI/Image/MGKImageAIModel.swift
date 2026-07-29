//
//  MGKImageAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-27.
//

import CoreImage
import Foundation
import ImageIO
import LocalImageGenerator
import MediaGenerationKit
import UIKit
import UniformTypeIdentifiers

enum MGKImageAIError: Error, Equatable {
    case pipelineNotLoaded
    case invalidModelID
    case imageLoadFailed
    case generationFailed
    case iamgeDecodeFailed

    var errorDescription: String? {
        switch self {
        case .pipelineNotLoaded:
            "Pipeline has not been loaded. Call load() first."
        case .invalidModelID:
            "Invalid model ID. Ensure the model is available in the Model Zoo."
        case .imageLoadFailed:
            "Input image data could not be loaded."
        case .generationFailed:
            "Image generation failed."
        case .iamgeDecodeFailed:
            "Decoding generate image result failed."
        }
    }
}

final class MGKImageAIModel: ImageAIModel {
    let modelID: String
    let inputSize: CGSize

    private var pipeline: MediaGenerationPipeline?

    init(
        modelID: String,
        inputSize: CGSize = CGSize(width: 512, height: 512)
    ) {
        self.modelID = modelID
        self.inputSize = inputSize
    }

    func load() async throws {
        // fetch model
        _ = try await MediaGenerationEnvironment.default.ensure(modelID)
        // load model
        var pipeline = try await MediaGenerationPipeline.fromPretrained(
            modelID,
            backend: .local
        )
        pipeline.configuration.width = Int(inputSize.width)
        pipeline.configuration.height = Int(inputSize.height)
        pipeline.configuration.strength = 1.0
        self.pipeline = pipeline
    }

    func edit(image: Data, prompt: String, options: ImageAIOptions) -> AsyncThrowingStream<
        ImageAIOutput, Error
    > {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard var pipeline else {
                        throw MGKImageAIError.pipelineNotLoaded
                    }

                    guard let cgImage = cgimageFromData(image) else {
                        throw MGKImageAIError.imageLoadFailed
                    }

                    let originalSize = CGSize(width: cgImage.width, height: cgImage.height)

                    pipeline.configuration.steps = options.steps
                    pipeline.configuration.seed = options.seed
                    pipeline.configuration.guidanceScale = options.guidance

                    let results = try await pipeline.generate(
                        prompt: prompt,
                        stateHandler: { state in
                            if case .generating(let step, _) = state {
                                continuation.yield(.progress(step: step))
                            }
                        }
                    )
                    guard let result = results.first else {
                        throw MGKImageAIError.generationFailed
                    }

                    let image = ImageConverter.image(from: result.tensor, scaleFactor: 1.0)
                    guard
                        let data = image.pngData(),
                        let restored = resize(data: data, to: originalSize)
                    else {
                        throw MGKImageAIError.iamgeDecodeFailed
                    }
                    continuation.yield(.image(image: restored))
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

    func resize(data: Data, to size: CGSize) -> Data? {
        guard let cgImage = cgimageFromData(data) else { return nil }
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        let resized = ciImage.transformed(
            by: CGAffineTransform(scaleX: scaleX, y: scaleY)
        )
        guard
            let png = context.pngRepresentation(
                of: resized,
                format: .RGBA8,
                colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
            )
        else { return nil }
        return png
    }

    func cgimageFromData(_ data: Data) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }
}
