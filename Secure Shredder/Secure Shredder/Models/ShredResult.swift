//
//  ShredResult.swift
//  SecureShredder
//
//  Results from shredding operations
//

import Foundation

/// Result of a shred operation
struct ShredResult {
    /// Total number of files processed
    let filesProcessed: Int

    /// Number of files successfully shredded
    let filesSucceeded: Int

    /// Number of files that failed
    let filesFailed: Int

    /// Total bytes shredded
    let bytesShredded: Int64

    /// Individual file results
    let fileResults: [FileResult]

    /// Files that had multiple hard links (st_nlink > 1).
    /// Overwriting one link may leave other links pointing to the same data blocks.
    let hardLinkedFiles: [URL]

    /// Whether the operation was cancelled
    let wasCancelled: Bool

    /// Time taken for the operation
    let duration: TimeInterval

    /// Result for an individual file
    struct FileResult {
        let url: URL
        let success: Bool
        let error: Error?
        let bytesWritten: Int64

        var fileName: String {
            url.lastPathComponent
        }
    }

    /// Success rate as a percentage
    var successRate: Double {
        guard filesProcessed > 0 else { return 0 }
        return Double(filesSucceeded) / Double(filesProcessed) * 100
    }

    /// Whether any hard-linked files were encountered
    var hasHardLinkedFiles: Bool {
        !hardLinkedFiles.isEmpty
    }

    /// Human-readable summary
    var summary: String {
        var parts: [String] = []

        if filesSucceeded > 0 {
            parts.append("\(filesSucceeded) file\(filesSucceeded == 1 ? "" : "s") shredded")
        }

        if filesFailed > 0 {
            parts.append("\(filesFailed) failed")
        }

        if wasCancelled {
            parts.append("cancelled")
        }

        if hasHardLinkedFiles {
            parts.append("\(hardLinkedFiles.count) hard-linked (other links may retain data)")
        }

        return parts.joined(separator: ", ")
    }
}
