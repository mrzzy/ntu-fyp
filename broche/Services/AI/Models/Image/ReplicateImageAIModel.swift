//
//  ReplicateImageAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-08-03.
//

import Foundation
import Replicate
import UIKit

enum ReplicateImageAIError: Swift.Error, LocalizedError, Equatable {
    case modelNotLoaded
    case invalidModelID(modelID: String)
    case invalidOutput
    case downloadFailed(url: String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "Model has not been loaded. Call load() first."
        case .invalidModelID(let id):
            "Invalid model identifier: '\(id)'"
        case .invalidOutput:
            "Model returned invalid output."
        case .downloadFailed(let url):
            "Failed to download output image from \(url)."
        }
    }
}

final class ReplicateImageAIModel: ImageAIModel {
    let modelID: String
    let secrets: Secrets
    private var client: Replicate.Client?

    init(modelID: String = "black-forest-labs/flux-2-klein-4b", secrets: Secrets) {
        self.modelID = modelID
        self.secrets = secrets
    }

    func load() async throws {
        client = try Replicate.Client(token: await secrets.replicateToken())
    }

    func edit(
        images: [Data],
        prompt: String,
        options: ImageAIOptions
    ) -> AsyncThrowingStream<ImageAIOutput, Swift.Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let client else {
                        throw ReplicateImageAIError.modelNotLoaded
                    }
                    guard let identifier = Identifier(rawValue: modelID) else {
                        throw ReplicateImageAIError.invalidModelID(modelID: modelID)
                    }

                    let jpegImages = images.compactMap { image -> Value? in
                        guard
                            let jpegData = UIImage(data: image)?.jpegData(
                                compressionQuality: 1
                            )
                        else { return nil }
                        return .data(mimeType: "image/jpeg", jpegData)
                    }
                    var input: [String: Value] = [
                        "prompt": .string(prompt),
                        "go_fast": .bool(false),
                        "images": .array(jpegImages),
                        "output_format": .string("png"),
                        "aspect_ratio": .string("match_input_image"),
                    ]
                    if options.seed != 0 {
                        input["seed"] = .int(Int(options.seed))
                    }

                    let outputURLs: [String]? = try await client.run(
                        identifier,
                        input: input,
                        [String].self
                    )
                    guard let outputURLs, let firstURLString = outputURLs.first,
                        let url = URL(string: firstURLString)
                    else {
                        throw ReplicateImageAIError.invalidOutput
                    }

                    // fetch generated image from output url
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard let httpResponse = response as? HTTPURLResponse,
                        (200..<300).contains(httpResponse.statusCode)
                    else {
                        throw ReplicateImageAIError.downloadFailed(url: firstURLString)
                    }

                    continuation.yield(
                        .image(
                            image: data,
                            metrics: ImageAIMetrics(nSamples: outputURLs.count, nSteps: 4)
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
