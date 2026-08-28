//
//  FirebaseSecretsTests.swift
//  brocheIntegrationTests
//  Created by Zhu Zhanyan on 2026-07-05.
//

import Foundation
import Testing

@testable import broche

/// Integration tests for ``FirebaseSecrets``.
///
/// These tests hit the real Firestore database and require:
/// - A valid `GoogleService-Info.plist` in the test target.
/// - Documents at `/credentials/openrouter` and `/credentials/replicate`
///   with a non-empty `token` string field.
@Suite("FirebaseSecrets tests")
struct FirebaseSecretsTests {
    private let secrets = FirebaseSecrets.shared

    /// Verifies that the OpenRouter token can be fetched and is non-empty.
    @Test("OpenRouter token is non-empty")
    func openRouterTokenIsNonEmpty() async throws {
        let token = try await secrets.openRouterToken()
        #expect(!token.isEmpty)
        print("OpenRouter token fetched successfully (", token.count, " chars)")
    }

    /// Verifies that the Replicate token can be fetched and is non-empty.
    @Test("Replicate token is non-empty")
    func replicateTokenIsNonEmpty() async throws {
        let token = try await secrets.replicateToken()
        #expect(!token.isEmpty)
        print("Replicate token fetched successfully (", token.count, " chars)")
    }
}

