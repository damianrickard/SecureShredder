//
//  ShredOperation.swift
//  SecureShredder
//
//  Represents an ongoing shred operation
//

import Foundation
import Combine

/// Represents an ongoing shred operation with progress tracking
class ShredOperation: ObservableObject {
    /// Current progress (0.0 to 1.0)
    @Published var progress: Double = 0.0

    /// Current file being processed
    @Published var currentFile: String = ""

    /// Current file index
    @Published var currentFileIndex: Int = 0

    /// Total number of files
    @Published var totalFiles: Int = 0

    /// Current status message
    @Published var statusMessage: String = ""

    /// Whether the operation is running
    @Published var isRunning: Bool = false

    /// Whether the operation is cancelled
    @Published var isCancelled: Bool = false

    /// Task handle for cancellation
    var task: Task<Void, Never>?

    /// Cancel the operation
    func cancel() {
        isCancelled = true
        task?.cancel()
    }

    /// Reset the operation
    func reset() {
        progress = 0.0
        currentFile = ""
        currentFileIndex = 0
        totalFiles = 0
        statusMessage = ""
        isRunning = false
        isCancelled = false
        task = nil
    }
}

/// Error types for shredding operations
enum ShredError: LocalizedError {
    case invalidConfiguration
    case fileNotFound(URL)
    case permissionDenied(URL)
    case fileOpenFailed(URL, String)
    case writeFailed(URL, String)
    case verificationFailed(URL)
    case encryptionFailed(URL, String)
    case deletionFailed(URL, Error)
    case cancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid shred configuration"
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .permissionDenied(let url):
            return "Permission denied: \(url.lastPathComponent)"
        case .fileOpenFailed(let url, let reason):
            return "Failed to open \(url.lastPathComponent): \(reason)"
        case .writeFailed(let url, let reason):
            return "Failed to write \(url.lastPathComponent): \(reason)"
        case .verificationFailed(let url):
            return "Verification failed: \(url.lastPathComponent)"
        case .encryptionFailed(let url, let reason):
            return "Failed to encrypt \(url.lastPathComponent): \(reason)"
        case .deletionFailed(let url, let error):
            return "Failed to delete \(url.lastPathComponent): \(error.localizedDescription)"
        case .cancelled:
            return "Operation cancelled"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Check file permissions and ensure you have write access"
        case .fileOpenFailed, .writeFailed:
            return "The file may be locked or in use by another application"
        case .verificationFailed:
            return "The file may be on a filesystem that doesn't support direct overwriting (like APFS)"
        default:
            return nil
        }
    }
}
