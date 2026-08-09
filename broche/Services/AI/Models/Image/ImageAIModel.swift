//
//  ImageAIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-20.
//

import Foundation

/// Image Editing AI Models
struct ImageAIOptions {
    /// Seed for random number generation to ensure reproducibility. 0 disables seed.
    var seed: UInt32 = 0
}

/// Metrics collected during
struct ImageAIMetrics {
    /// No. of samples generated
    var nSamples: Int = 0
    /// No. of image generation steps run.
    var nSteps: Int = 0
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

/// Benchmarks an ``ImageAIModel`` by editing a fixed test image with a fixed prompt
/// and collecting model-reported metrics.
///
/// Conforms to ``AIBenchmark``. Use ``evaluate(_:)`` to load the model,
/// run editing, and collect timings and memory usage.
class ImageAIBenchmark<Model: ImageAIModel>: AIBenchmark {
    /// Edited image produced during the benchmark.
    var outputImage: Data?

    func generate(_ model: Model) async throws -> AIMetrics {
        outputImage = nil

        // load test image
        let url = Bundle.main.url(
            forResource: "apple_sketch",
            withExtension: "png"
        )!
        let imageData = try Data(contentsOf: url)

        let stream = model.edit(
            image: imageData,
            prompt: "Render apple, plate & cup in a watercolor painting, transparent washes, pigment granulation, color bleeding, wet-on-wet technique, loose expressive brushstrokes, soft edges, subtle gradients, natural pigments",
            options: ImageAIOptions(seed: 42)
        )
        for try await output in stream {
            switch output {
            case .progress:
                break
            case .image(let data, let metrics):
                outputImage = data
                if let metrics {
                    return .image(metrics)
                }
            }
        }
        throw AIBenchmarkError.NoMetricsReported
    }
}
