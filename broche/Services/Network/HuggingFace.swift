//
//  HuggingFace.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-23.
//

import Foundation
import HuggingFace

/// Errors that can occur when downloading models from HuggingFace Hub.
enum HuggingFaceDownloaderError: Error, LocalizedError {
    /// The given string is not a valid HuggingFace repository identifier.
    case invalidRepositoryID(String)
    /// No file matching the requested pattern was found in the downloaded snapshot.
    case fileNotFound(directory: String, pattern: String)

    var errorDescription: String? {
        switch self {
        case .invalidRepositoryID(let id):
            "Invalid HuggingFace repository ID: \(id)"
        case .fileNotFound(let directory, let pattern):
            "No file matching '\(pattern)' found in '\(directory)'"
        }
    }
}

/// Downloads model files from HuggingFace Hub and locates them on disk.
///
/// Uses ``HubClient`` for network access and respects its default cache,
/// so previously downloaded snapshots are served from disk without re-fetching.
struct HuggingFaceDownloader {
    /// The Hub client used for API requests and caching.
    private let client: HubClient

    /// Creates a downloader backed by the given Hub client.
    ///
    /// - Parameter client: A ``HubClient`` instance. Defaults to ``HubClient/default``,
    ///   which auto-detects credentials from the environment.
    init(client: HubClient = .default) {
        self.client = client
    }

    /// Downloads a repository snapshot matching the given glob patterns.
    ///
    /// Uses the Hub cache so previously downloaded files are not re-fetched.
    ///
    /// - Parameters:
    ///   - repoID: A HuggingFace repository identifier (e.g. `"google/gemma-2b"`).
    ///   - patterns: Glob patterns to filter which files to download (e.g. `["*.litertlm"]`).
    ///   - progressHandler: Optional callback invoked as the download progresses.
    /// - Returns: The directory URL containing the downloaded files.
    func downloadSnapshot(
        repoID: String,
        matching patterns: [String],
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws -> URL {
        guard let repo = Repo.ID(rawValue: repoID) else {
            throw HuggingFaceDownloaderError.invalidRepositoryID(repoID)
        }
        return try await client.downloadSnapshot(
            of: repo,
            matching: patterns,
            progressHandler: { @MainActor progress in
                progressHandler(progress)
            }
        )
    }

    /// Recursively searches a directory for the first file whose name ends with `suffix`.
    ///
    /// - Parameters:
    ///   - directory: The root directory to search.
    ///   - suffix: A file extension or suffix to match (e.g. `"litertlm"`).
    /// - Returns: The URL of the first matching file, or `nil` if none is found.
    func findFile(in directory: URL, withSuffix suffix: String) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return nil }

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent.hasSuffix(suffix) else { continue }
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
                !isDir.boolValue
            {
                return fileURL
            }
        }
        return nil
    }
}
