//
//  ImageAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-20.
//

import Foundation

/// Image Editing AI Models
struct ImageAIOptions {
    /// The number of steps to perform during the editing process. More iterations may yield better results but take longer.
    var steps: Int = 8
    /// The scale factor for prompt guidance during the editing process. Higher values may produce more pronounced edits.
    var guidance: Float = 7.5
    /// The strength of the editing effect. A value of 0.0 means no change from original image, while 1.0 means full application of the edits.
    var strength: Float = 0.8
    /// Seed for random number generation to ensure reproducibility.
    var seed: UInt32 = 0
}

/// Metrics collected during
struct ImageAIMetrics {
    /// No. of samples generated
    var nSamples: Int = 0
}

/// Output from an image AI model, either progress updates or the final image
enum ImageAIOutput {
    /// Progress update during image generation
    case progress(step: Int)
    /// Final edited image with generation metrics
    case image(image: Data, metrics: ImageAIMetrics? = nil)
}

/// Image Editing AI Model
protocol ImageAIModel: AIModel {
    /// Edits an image based on the provided prompt and options.
    ///
    /// - Parameters:
    ///   - image: The input image to be edited.
    ///   - prompt: The textual description guiding the edits.
    ///   - options: Configuration controlling the editing process.
    /// - Returns: An async throwing stream of output updates (progress or final image).
    func edit(
        image: Data,
        prompt: String,
        options: ImageAIOptions
    ) -> AsyncThrowingStream<ImageAIOutput, Error>
}
