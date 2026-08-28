//
//  FirebaseSecrets.swift
//  broche
//  Created by Zhu Zhanyan on 2026-07-05.
//

import FirebaseFirestore

/// Errors that can occur when retrieving secrets from Firestore.
///
/// Each case carries the Firestore document path that caused the failure
/// to aid debugging and logging.
enum FirebaseSecretsError: Swift.Error, LocalizedError, Equatable {
    /// The specified Firestore document does not exist.
    case documentNotFound(path: String)
    /// The document exists but its ``token`` field is missing or empty.
    case tokenEmpty(path: String)

    var errorDescription: String? {
        switch self {
        case .documentNotFound(let path):
            "Secrets document not found at \(path)."
        case .tokenEmpty(let path):
            "Token field is empty or missing in \(path)."
        }
    }
}

/// Provides access to API tokens stored as Firestore documents.
///
/// Each credential is a Firestore document containing a `token` string field.
/// Available credentials:
/// - ``openRouterToken()`` — `/credentials/openrouter`
/// - ``replicateToken()`` — `/credentials/replicate`
///
/// All methods are `async throws` and require a valid Firebase configuration
/// (i.e. `FirebaseApp.configure()` must have been called).
struct FirebaseSecrets: Secrets {
    private let db = Firestore.firestore()
    static let shared = FirebaseSecrets()

    private init() {}

    func openRouterToken() async throws -> String {
        try await token(for: "credentials/openrouter")
    }

    func replicateToken() async throws -> String {
        try await token(for: "credentials/replicate")
    }

    private func token(for path: String) async throws -> String {
        let snapshot = try await db.document(path).getDocument()
        guard snapshot.exists else {
            throw FirebaseSecretsError.documentNotFound(path: path)
        }
        guard let token = snapshot.get("token") as? String, !token.isEmpty else {
            throw FirebaseSecretsError.tokenEmpty(path: path)
        }
        return token
    }
}
