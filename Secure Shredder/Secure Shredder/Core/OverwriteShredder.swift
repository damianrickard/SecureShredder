//
//  OverwriteShredder.swift
//  SecureShredder
//
//  In-place overwrite for traditional (non-CoW) filesystems
//
//  On traditional filesystems like HFS+, exFAT, and FAT32, overwriting
//  a file actually replaces the data in the same disk blocks. This makes
//  direct overwrite an effective secure deletion method.
//
//  Implements the DoD 5220.22-M standard:
//    Each pass cycle writes three patterns:
//      1. All zeros (0x00)
//      2. All ones (0xFF)
//      3. Cryptographically random data
//    The standard 3-pass mode performs one cycle (3 patterns).
//    The 7-pass mode performs two full cycles plus a final random pass.
//

import Foundation
import Security
import CryptoKit

/// DoD 5220.22-M pass pattern
enum DoDPattern {
    case zeros
    case ones
    case random

    /// Human-readable name for progress display
    var displayName: String {
        switch self {
        case .zeros:  return "zeros (0x00)"
        case .ones:   return "ones (0xFF)"
        case .random: return "random data"
        }
    }
}

/// Performs best-effort in-place overwrite on non-CoW filesystems (e.g., HFS+, exFAT)
final class OverwriteShredder {
    typealias ProgressCallback = (Double, String) -> Void

    /// Generate the sequence of DoD 5220.22-M patterns for a given pass count.
    ///
    /// - 1 pass:  [random]  (quick single-pass mode)
    /// - 3 passes: [zeros, ones, random]  (standard DoD)
    /// - 7 passes: [zeros, ones, random, zeros, ones, random, random]  (extended DoD)
    /// - Other N:  repeat (zeros, ones, random) cycles, ending with random
    static func patternSequence(forPasses passes: Int) -> [DoDPattern] {
        guard passes > 0 else { return [.random] }

        if passes == 1 {
            return [.random]
        }

        // Build full cycles of 3 (zeros, ones, random)
        let fullCycles = passes / 3
        let remainder = passes % 3

        var patterns: [DoDPattern] = []
        for _ in 0..<fullCycles {
            patterns.append(contentsOf: [.zeros, .ones, .random])
        }

        // Fill remaining passes: prefer ending with random
        switch remainder {
        case 1:
            patterns.append(.random)
        case 2:
            patterns.append(.zeros)
            patterns.append(.random)
        default:
            break
        }

        return patterns
    }

    /// Overwrite a file in place following DoD 5220.22-M patterns.
    /// - Parameters:
    ///   - url: File URL to overwrite
    ///   - passes: Number of overwrite passes (1, 3, or 7 recommended)
    ///   - chunkSize: Size of I/O chunks (default 1MB)
    ///   - verify: Whether to read back and verify the final pass
    ///   - progress: Optional progress callback (0..1, status)
    /// - Throws: ShredError if operation fails
    func overwriteFile(
        at url: URL,
        passes: Int = 3,
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

        clearImmutableIfNeeded(at: url.path)

        let path = url.path
        let patterns = Self.patternSequence(forPasses: passes)
        let totalPatterns = patterns.count

        // Open for read+write (need read for verification)
        let fd = open(path, O_RDWR | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ELOOP {
                throw ShredError.writeFailed(url, "Refusing to follow symbolic link")
            }
            throw ShredError.fileOpenFailed(url, String(cString: strerror(errno)))
        }
        defer { close(fd) }

        // Disable caching to push writes directly to disk
        _ = fcntl(fd, F_NOCACHE, 1)

        // Determine file size
        var st = stat()
        guard fstat(fd, &st) == 0 else {
            throw ShredError.fileOpenFailed(url, "fstat failed: \(String(cString: strerror(errno)))")
        }

        let fileSize = Int64(st.st_size)
        guard fileSize > 0 else {
            progress?(1.0, "Empty file, skipping")
            return
        }

        // Prepare buffer
        let bufSize = max(4096, chunkSize)
        var buffer = [UInt8](repeating: 0, count: bufSize)

        // For random-pass verification, we compute a SHA-256 hash of what we wrote
        // then read it back and compare hashes chunk-by-chunk.
        var lastPattern: DoDPattern = .random
        var writtenRandomHash: SHA256Digest?

        for (passIndex, pattern) in patterns.enumerated() {
            lastPattern = pattern

            // Check cancellation before each pass
            if Task.isCancelled {
                zeroBuffer(&buffer)
                throw ShredError.cancelled
            }

            // Seek to beginning for this pass
            guard lseek(fd, 0, SEEK_SET) == 0 else {
                zeroBuffer(&buffer)
                throw ShredError.writeFailed(url, "Failed to seek: \(String(cString: strerror(errno)))")
            }

            let passLabel = "Pass \(passIndex + 1)/\(totalPatterns): \(pattern.displayName)"
            let passBaseProgress = Double(passIndex) / Double(totalPatterns)
            let passWeight = 1.0 / Double(totalPatterns)

            var remaining = fileSize

            // For the last pass, if random, compute a running hash of what we write
            let isLastPass = passIndex == totalPatterns - 1
            let trackHash = isLastPass && pattern == .random && verify
            var hasher: SHA256? = trackHash ? SHA256() : nil

            while remaining > 0 {
                // Check cancellation within chunk loop
                if Task.isCancelled {
                    zeroBuffer(&buffer)
                    throw ShredError.cancelled
                }

                let toWrite = Int(min(Int64(bufSize), remaining))

                // Fill buffer with the appropriate pattern
                try fillBuffer(&buffer, count: toWrite, pattern: pattern)

                // If tracking, feed written bytes into hash
                if trackHash {
                    buffer.withUnsafeBufferPointer { ptr in
                        hasher!.update(bufferPointer: UnsafeRawBufferPointer(
                            start: ptr.baseAddress, count: toWrite
                        ))
                    }
                }

                // Write to file
                let written = buffer.withUnsafeBytes { ptr in
                    write(fd, ptr.baseAddress!, toWrite)
                }

                if written < 0 {
                    zeroBuffer(&buffer)
                    throw ShredError.writeFailed(url, String(cString: strerror(errno)))
                }
                if written != toWrite {
                    zeroBuffer(&buffer)
                    throw ShredError.writeFailed(url, "Short write: \(written) of \(toWrite)")
                }

                remaining -= Int64(written)

                let chunkProgress = Double(fileSize - remaining) / Double(fileSize)
                let overallProgress = passBaseProgress + chunkProgress * passWeight
                progress?(overallProgress, passLabel)

                await Task.yield()
            }

            // Finalize hash for this pass
            if trackHash, let h = hasher {
                writtenRandomHash = h.finalize()
            }

            // Flush after each pass to ensure data reaches disk
            fsync(fd)
            _ = fcntl(fd, F_FULLFSYNC)
        }

        // Verification: read back final pass and check pattern
        if verify {
            try verifyFinalPass(
                fd: fd,
                fileSize: fileSize,
                pattern: lastPattern,
                buffer: &buffer,
                url: url,
                expectedRandomHash: writtenRandomHash
            )
        }

        // Zero the buffer before deallocation
        zeroBuffer(&buffer)

        progress?(1.0, "Overwrite complete (\(totalPatterns) passes)")
    }

    // MARK: - Private Helpers

    /// Fill buffer with the specified DoD pattern
    private func fillBuffer(_ buffer: inout [UInt8], count: Int, pattern: DoDPattern) throws {
        switch pattern {
        case .zeros:
            _ = buffer.withUnsafeMutableBytes { ptr in
                memset(ptr.baseAddress!, 0x00, count)
            }
        case .ones:
            _ = buffer.withUnsafeMutableBytes { ptr in
                memset(ptr.baseAddress!, 0xFF, count)
            }
        case .random:
            let status = SecRandomCopyBytes(kSecRandomDefault, count, &buffer)
            if status != errSecSuccess {
                throw ShredError.writeFailed(URL(fileURLWithPath: "/"), "Failed to generate random data")
            }
        }
    }

    /// Verify the final pass by reading data back and checking it matches the expected pattern.
    /// For zeros/ones passes: byte-by-byte comparison against the expected value.
    /// For random passes: SHA-256 hash comparison against the hash computed during writing.
    private func verifyFinalPass(
        fd: Int32,
        fileSize: Int64,
        pattern: DoDPattern,
        buffer: inout [UInt8],
        url: URL,
        expectedRandomHash: SHA256Digest?
    ) throws {
        guard lseek(fd, 0, SEEK_SET) == 0 else {
            throw ShredError.verificationFailed(url)
        }

        var remaining = fileSize
        let bufSize = buffer.count

        // For random verification, compute a running hash of read-back data
        var readHasher: SHA256? = (pattern == .random && expectedRandomHash != nil) ? SHA256() : nil

        while remaining > 0 {
            let toRead = Int(min(Int64(bufSize), remaining))
            let bytesRead = buffer.withUnsafeMutableBytes { ptr in
                read(fd, ptr.baseAddress!, toRead)
            }

            guard bytesRead == toRead else {
                throw ShredError.verificationFailed(url)
            }

            switch pattern {
            case .zeros:
                for i in 0..<toRead {
                    if buffer[i] != 0x00 {
                        throw ShredError.verificationFailed(url)
                    }
                }
            case .ones:
                for i in 0..<toRead {
                    if buffer[i] != 0xFF {
                        throw ShredError.verificationFailed(url)
                    }
                }
            case .random:
                // Feed read-back data into hash for comparison
                if readHasher != nil {
                    buffer.withUnsafeBufferPointer { ptr in
                        readHasher!.update(bufferPointer: UnsafeRawBufferPointer(
                            start: ptr.baseAddress, count: toRead
                        ))
                    }
                }
            }

            remaining -= Int64(bytesRead)
        }

        // For random pass: compare the hash of what was written vs what was read back
        if pattern == .random, let expectedHash = expectedRandomHash, let hasher = readHasher {
            let readHash = hasher.finalize()
            // Compare digests byte-by-byte
            let expected = Array(expectedHash)
            let actual = Array(readHash)
            if expected != actual {
                throw ShredError.verificationFailed(url)
            }
        }
    }

    /// Zero buffer contents using memset_s to prevent compiler optimization from eliding the zeroing
    private func zeroBuffer(_ buffer: inout [UInt8]) {
        buffer.withUnsafeMutableBytes { ptr in
            _ = memset_s(ptr.baseAddress!, ptr.count, 0, ptr.count)
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
