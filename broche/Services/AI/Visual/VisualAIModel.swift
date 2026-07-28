//
//  VisualAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-28
//

import Foundation

/// Visual Language Generation AI models aka (VLMs)
/// Options that control visual text generation.
typealias VisualAIOptions = TextAIOptions

/// Metrics collected during visual text generation.
typealias VisualAIMetrics = TextAIMetrics

/// Errors that can occur during visual text generation.
enum VisualAIError: Error, LocalizedError {
    case modelNotLoaded
    case imageDecodingFailed
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model has not been loaded. Call load(:) first."
        case .imageDecodingFailed:
            return "Failed to decode the provided image data."
        }
    }
}

/// The output of a visual text generation model
typealias VisualAIOutput = TextAIOutput

protocol VisualAIModel: AIModel {
    /// Generates text for the given prompt.
    ///
    /// - Parameters:
    ///   - prompt: The input prompt to generate a completion for.
    ///   - images: PNG encoded images as data to be used as visual context for generation.
    ///   - options: Configuration controlling text generation.
    /// - Returns: An asynchronous stream of generated text chunks.
    /// - Throws: An error if generation fails or the model has not been loaded.
    func generate(
        prompt: String,
        images: [Data],
        options: VisualAIOptions
    ) -> AsyncThrowingStream<VisualAIOutput, Error>
}

