//
//  ReplicateImageAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-08-03.
//

import UIKit
import CloudKit
import Foundation
import Replicate

enum ReplicateImageAIError: Swift.Error, LocalizedError, Equatable {
    case modelNotLoaded
    case invalidModelID(modelID: String)
    case invalidOutput
    case downloadFailed(url: String)
    case tokenNotFound

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            "Model has not been loaded. Call load() first."
        case let .invalidModelID(id):
            "Invalid model identifier: '\(id)'"
        case .invalidOutput:
            "Model returned invalid output."
        case let .downloadFailed(url):
            "Failed to download output image from \(url)."
        case .tokenNotFound:
            "Replicate API token not found in CloudKit."
        }
    }
}

final class ReplicateImageAIModel: ImageAIModel {
    let modelID: String
    private var client: Replicate.Client?

    init(modelID: String = "black-forest-labs/flux-2-klein-4b") {
        self.modelID = modelID
    }

    func load() async throws {
        let recordID = CKRecord.ID(recordName: "replicateToken")
        let record = try await CKContainer(identifier: "iCloud.inc.cloudKitTest")
            .publicCloudDatabase.record(for: recordID)
        guard let token = record["token"] as? String, !token.isEmpty else {
            throw ReplicateImageAIError.tokenNotFound
        }
        client = Replicate.Client(token: token)
    }

    func edit(
        image: Data,
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

                    // 1MB size limit
                    let jpegData = UIImage(data: image)!.jpegData(compressionQuality: 1)!
                    var input: [String: Value] = [
                        "prompt": .string(prompt),
                        // enable additional optimisations
                        "go_fast": .bool(true),
                        "images": .array([.data(mimeType: "image/jpeg", jpegData)]),
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
                          (200 ..< 300).contains(httpResponse.statusCode)
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
