//
//  Filesystem.swift
//  broche
//
//  Created by Zhu Zhanyan on 2026-07-23.
//

import Foundation

/// Filesystem utility functions.
class Filesystem {
    /// Recursively searches a directory for the first file whose name ends with `suffix`.
    ///
    /// - Parameters:
    ///   - directory: The root directory to search.
    ///   - suffix: A file extension or suffix to match (e.g. `"litertlm"`).
    /// - Returns: The URL of the first matching file, or `nil` if none is found.
    static func findFile(in directory: URL, withSuffix suffix: String) -> URL? {
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
        else { return nil }

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
