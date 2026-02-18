//
//  FileDiscovery.swift
//  SecureShredder
//
//  Recursive file enumeration for directories
//

import Foundation

/// Handles recursive discovery of files in directories
class FileDiscovery {
    /// Discovered file information
    struct DiscoveredFile {
        let url: URL
        let size: Int64
        let isDirectory: Bool
    }

    /// Recursively discover all files in the given URLs.
    /// Symbolic links are detected and skipped to prevent symlink traversal attacks.
    /// - Parameter urls: Array of file/directory URLs
    /// - Returns: Array of discovered files (directories and symlinks excluded)
    /// - Throws: Error if enumeration fails
    func discoverFiles(in urls: [URL]) throws -> [DiscoveredFile] {
        var allFiles: [DiscoveredFile] = []

        for url in urls {
            try discoverFiles(at: url, accumulator: &allFiles)
        }

        return allFiles
    }

    /// Recursively discover files at a single URL
    private func discoverFiles(at url: URL, accumulator: inout [DiscoveredFile]) throws {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default

        // Check if path exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw ShredError.fileNotFound(url)
        }

        // Check if this is a symlink — skip it
        let resourceValues = try url.resourceValues(forKeys: [
            .isDirectoryKey,
            .fileSizeKey,
            .isSymbolicLinkKey
        ])

        if resourceValues.isSymbolicLink == true {
            // Skip symbolic links to prevent symlink traversal attacks
            return
        }

        let isDirectory = resourceValues.isDirectory ?? false

        if isDirectory {
            // Recursively enumerate directory contents (including hidden files)
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey],
                options: []  // Don't skip hidden files - secure deletion should delete everything
            ) else {
                throw ShredError.permissionDenied(url)
            }

            for case let itemURL as URL in enumerator {
                let itemValues = try itemURL.resourceValues(forKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .isSymbolicLinkKey
                ])

                // Skip symbolic links
                if itemValues.isSymbolicLink == true {
                    if itemValues.isDirectory == true {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                let itemIsDirectory = itemValues.isDirectory ?? false

                // Only add files, not directories
                if !itemIsDirectory {
                    let size = Int64(itemValues.fileSize ?? 0)
                    accumulator.append(DiscoveredFile(
                        url: itemURL,
                        size: size,
                        isDirectory: false
                    ))
                }
            }
        } else {
            // Add single file
            let size = Int64(resourceValues.fileSize ?? 0)
            accumulator.append(DiscoveredFile(
                url: url,
                size: size,
                isDirectory: false
            ))
        }
    }

    /// Calculate total size of all files
    /// - Parameter files: Array of discovered files
    /// - Returns: Total size in bytes
    func totalSize(of files: [DiscoveredFile]) -> Int64 {
        files.reduce(0) { $0 + $1.size }
    }
}
