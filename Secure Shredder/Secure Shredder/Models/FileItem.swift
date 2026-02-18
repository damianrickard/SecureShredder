//
//  FileItem.swift
//  SecureShredder
//
//  Represents a file or folder to be shredded
//

import Foundation

/// Represents a file item to be shredded
struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool
    let size: Int64

    /// Human-readable file size
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// File name for display
    var displayName: String {
        url.lastPathComponent
    }

    /// Initialize from URL
    init(url: URL) throws {
        self.url = url

        let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        self.isDirectory = resourceValues.isDirectory ?? false

        if isDirectory {
            // Calculate total size of directory contents
            self.size = FileItem.calculateDirectorySize(at: url)
        } else {
            self.size = Int64(resourceValues.fileSize ?? 0)
        }
    }

    /// Calculate the total size of all files in a directory recursively
    private static func calculateDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default

        // Request access to security-scoped resource
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: []  // Don't skip hidden files
        ) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                // Only count files, not directories
                if resourceValues.isDirectory != true {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                // Skip files we can't read
                continue
            }
        }

        return totalSize
    }

    /// Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}
