//
//  Secrets.swift
//  broche
//  Created by Zhu Zhanyan on 2026-07-05.
//

/// Provides access to API tokens.
protocol Secrets {
    /// Fetches the OpenRouter API token.
    ///
    /// - Returns: A non-empty API token string.
    func openRouterToken() async throws -> String

    /// Fetches the Replicate API token.
    ///
    /// - Returns: A non-empty API token string.
    func replicateToken() async throws -> String
}
