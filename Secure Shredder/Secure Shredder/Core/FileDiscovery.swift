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
        /// Number of hard links to this file (st_nlink).
        /// A value > 1 means other directory entries point to the same data blocks.
        let hardLinkCount: UInt16
        /// True when hardLinkCount > 1
        var isHardLinked: Bool { hardLinkCount > 1 }
    }

    /// Recursively discover all files in the given URLs.
    /// Symbolic links are detected and skipped to prevent symlink traversal attacks.
    /// Hard-linked files are flagged so the engine can warn the user.
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
                    let nlink = Self.hardLinkCount(at: itemURL)
                    accumulator.append(DiscoveredFile(
                        url: itemURL,
                        size: size,
                        isDirectory: false,
                        hardLinkCount: nlink
                    ))
                }
            }
        } else {
            // Add single file
            let size = Int64(resourceValues.fileSize ?? 0)
            let nlink = Self.hardLinkCount(at: url)
            accumulator.append(DiscoveredFile(
                url: url,
                size: size,
                isDirectory: false,
                hardLinkCount: nlink
            ))
        }
    }

    /// Read the hard-link count (st_nlink) for a file using stat()
    private static func hardLinkCount(at url: URL) -> UInt16 {
        var st = stat()
        guard stat(url.path, &st) == 0 else { return 1 }
        return st.st_nlink
    }

    /// Calculate total size of all files
    /// - Parameter files: Array of discovered files
    /// - Returns: Total size in bytes
    func totalSize(of files: [DiscoveredFile]) -> Int64 {
        files.reduce(0) { $0 + $1.size }
    }
}
