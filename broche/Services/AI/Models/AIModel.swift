//
//  AIModel.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-20.
//

/// A minimal interface for AI models
protocol AIModel {
    /// String identifier of the model
    var modelID: String { get }

    /// Loads the model weights of a model for inference.
    ///
    /// - Throws: An error if the model cannot be found, loaded, or initialized.
    func load() async throws
}
