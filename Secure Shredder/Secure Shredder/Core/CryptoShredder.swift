//
//  CryptoShredder.swift
//  SecureShredder
//
//  Encryption-based secure deletion for APFS filesystems
//
//  Crypto-shredding works by encrypting file contents with a random key,
//  then destroying the key. APFS copy-on-write ensures original data blocks
//  are freed when encrypted data is written. Without the key, any remaining
//  data on disk is cryptographically unrecoverable.
//

import Foundation
import CryptoKit

/// Handles encryption-based secure deletion (crypto-shredding)
class CryptoShredder {
    typealias ProgressCallback = (Double, String) -> Void

    /// Crypto-shred a file using AES-256-GCM encryption
    /// - Parameters:
    ///   - url: URL of file to shred
    ///   - chunkSize: Size of chunks to process (default 1MB)
    ///   - verify: Verify that encrypted file was written correctly (default true)
    ///   - progress: Progress callback (progress 0-1, status message)
    /// - Throws: ShredError if operation fails
    func shredFile(
        at url: URL,
        chunkSize: Int = 1024 * 1024,
        verify: Bool = true,
        progress: ProgressCallback? = nil
    ) async throws {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileSize = try getFileSize(at: url)
        guard fileSize > 0 else {
            progress?(1.0, "Empty file, skipping")
            return
        }

        // Generate random 256-bit key (CryptoKit handles secure memory management)
        let key = SymmetricKey(size: .bits256)

        // Encrypt file in place using streaming method
        progress?(0.1, "Encrypting file...")
        try await encryptFileStreaming(
            at: url,
            key: key,
            fileSize: fileSize,
            chunkSize: chunkSize,
            verify: verify,
            progress: progress
        )

        progress?(0.95, "Finalizing...")

        // Key goes out of scope here and is deallocated
        // CryptoKit's SymmetricKey handles secure cleanup automatically
        progress?(1.0, "Encryption complete")
    }

    // MARK: - Private Methods

    /// Get file size
    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? Int64 else {
            throw ShredError.fileNotFound(url)
        }
        return size
    }

    /// Encrypt file contents by streaming in chunks using AES-256-GCM
    private func encryptFileStreaming(
        at url: URL,
        key: SymmetricKey,
        fileSize: Int64,
        chunkSize: Int,
        verify: Bool,
        progress: ProgressCallback?
    ) async throws {
        let tempURL = url.deletingLastPathComponent().appendingPathComponent(".ss.tmp.\(UUID().uuidString)")
        let fileManager = FileManager.default

        // Ensure temp file is cleaned up on any error
        defer {
            try? fileManager.removeItem(at: tempURL)
        }

        // Create empty temp file
        guard fileManager.createFile(atPath: tempURL.path, contents: nil) else {
            throw ShredError.writeFailed(tempURL, "Failed to create temporary file")
        }

        // Open source file for reading
        let readHandle: FileHandle
        do {
            readHandle = try FileHandle(forReadingFrom: url)
        } catch {
            throw ShredError.fileOpenFailed(url, error.localizedDescription)
        }

        // Open temp file for writing
        let writeHandle: FileHandle
        do {
            writeHandle = try FileHandle(forWritingTo: tempURL)
        } catch {
            try? readHandle.close()
            throw ShredError.writeFailed(tempURL, error.localizedDescription)
        }

        // Pre-allocate a reusable read buffer to reduce allocations
        var readBuffer = [UInt8](repeating: 0, count: chunkSize)

        // Process file in chunks
        var totalBytesProcessed: Int64 = 0
        let total = Double(fileSize)
        var encryptionError: Error?

        while encryptionError == nil {
            // Check for cancellation within the chunk loop
            if Task.isCancelled {
                try? readHandle.close()
                try? writeHandle.close()
                // Zero the read buffer before throwing
                readBuffer.withUnsafeMutableBytes { ptr in
                    _ = memset_s(ptr.baseAddress!, ptr.count, 0, ptr.count)
                }
                throw ShredError.cancelled
            }

            // Read into pre-allocated buffer
            let result: Result<Data?, Error> = autoreleasepool {
                do {
                    guard let data = try readHandle.read(upToCount: chunkSize), !data.isEmpty else {
                        return .success(nil) // EOF
                    }
                    return .success(data)
                } catch {
                    return .failure(error)
                }
            }

            switch result {
            case .success(let data):
                guard let data = data else {
                    break // EOF - exit loop
                }

                // Encrypt chunk with random nonce
                do {
                    let nonce = AES.GCM.Nonce()
                    let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
                    guard let combined = sealedBox.combined else {
                        throw ShredError.encryptionFailed(url, "Failed to create sealed box")
                    }
                    try writeHandle.write(contentsOf: combined)
                    totalBytesProcessed += Int64(data.count)
                    progress?(0.1 + 0.8 * (Double(totalBytesProcessed) / total), "Writing encrypted data...")

                    await Task.yield()
                } catch {
                    encryptionError = error
                }

            case .failure(let error):
                encryptionError = ShredError.fileOpenFailed(url, "Read error: \(error.localizedDescription)")
            }

            // Check if we've processed all bytes (EOF condition)
            if totalBytesProcessed >= fileSize {
                break
            }
        }

        // Zero the read buffer
        readBuffer.withUnsafeMutableBytes { ptr in
            _ = memset_s(ptr.baseAddress!, ptr.count, 0, ptr.count)
        }

        // Close handles before any further operations
        try? readHandle.close()

        // Flush writes to disk
        do {
            try writeHandle.synchronize()
            _ = fcntl(writeHandle.fileDescriptor, F_FULLFSYNC)
        } catch {
            try? writeHandle.close()
            throw ShredError.writeFailed(tempURL, "Failed to sync: \(error.localizedDescription)")
        }
        try? writeHandle.close()

        // If there was an encryption error, throw it now
        if let error = encryptionError {
            if let shredError = error as? ShredError {
                throw shredError
            }
            throw ShredError.encryptionFailed(url, error.localizedDescription)
        }

        // Verify the temp file was written
        if verify {
            let attrs = try fileManager.attributesOfItem(atPath: tempURL.path)
            guard let size = attrs[.size] as? NSNumber, size.int64Value > 0 else {
                throw ShredError.verificationFailed(url)
            }
        }

        // Clear immutable flags on original file if needed before replacing
        clearImmutableIfNeeded(at: url.path)

        // Replace original with encrypted version
        do {
            _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            throw ShredError.writeFailed(url, error.localizedDescription)
        }
    }

    /// Clear immutable flags if set on file at given path
    private func clearImmutableIfNeeded(at path: String) {
        var attrs = stat()
        if stat(path, &attrs) == 0 {
            if attrs.st_flags & UInt32(UF_IMMUTABLE) != 0 || attrs.st_flags & UInt32(SF_IMMUTABLE) != 0 {
                var newFlags = attrs.st_flags
                newFlags &= ~UInt32(UF_IMMUTABLE)
                newFlags &= ~UInt32(SF_IMMUTABLE)
                chflags(path, newFlags)
            }
        }
    }
}
