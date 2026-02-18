//
//  SecureDeletion.swift
//  SecureShredder
//
//  Secure file deletion bypassing Trash
//

import Foundation

/// Handles secure deletion of files and directories
class SecureDeletion {
    private let fileManager = FileManager.default

    /// Securely delete a file (bypassing Trash)
    /// - Parameter url: URL of file to delete
    /// - Throws: ShredError if deletion fails
    func deleteFile(at url: URL) throws {
        // Request access to security-scoped resource (required for sandboxed apps)
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Unlock file if needed (remove immutable flag)
        try unlockFile(at: url)

        // Delete file directly (bypasses Trash when done programmatically)
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ShredError.deletionFailed(url, error)
        }
    }

    /// Delete a directory and all its contents
    /// - Parameter url: URL of directory to delete
    /// - Throws: ShredError if deletion fails
    func deleteDirectory(at url: URL) throws {
        // Request access to security-scoped resource (required for sandboxed apps)
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // For directories, just remove them after files are shredded
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ShredError.deletionFailed(url, error)
        }
    }

    /// Unlock a file by removing immutable flags using chflags
    /// - Parameter url: URL of file to unlock
    private func unlockFile(at url: URL) throws {
        let path = url.path

        // Use chflags to clear both user and system immutable flags
        // This is more reliable than FileManager.setAttributes which only handles user flags
        var attrs = stat()
        guard stat(path, &attrs) == 0 else {
            return  // Can't stat file, proceed anyway
        }

        // Check if any immutable flags are set
        let hasUserImmutable = attrs.st_flags & UInt32(UF_IMMUTABLE) != 0
        let hasSystemImmutable = attrs.st_flags & UInt32(SF_IMMUTABLE) != 0

        if hasUserImmutable || hasSystemImmutable {
            var newFlags = attrs.st_flags
            newFlags &= ~UInt32(UF_IMMUTABLE)
            newFlags &= ~UInt32(SF_IMMUTABLE)

            // Attempt to clear flags - ignore errors as we may not have permission
            // for system flags, but user flags should work
            _ = chflags(path, newFlags)
        }
    }

    /// Check if a file/directory can be deleted
    /// - Parameter url: URL to check
    /// - Returns: true if deletable
    func isDeletable(at url: URL) -> Bool {
        fileManager.isDeletableFile(atPath: url.path)
    }
}
