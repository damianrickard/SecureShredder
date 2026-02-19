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

    /// Securely delete a file (bypassing Trash).
    /// Strips extended attributes and resource forks before removal to reduce metadata leakage.
    /// - Parameter url: URL of file to delete
    /// - Throws: ShredError if deletion fails
    func deleteFile(at url: URL) throws {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Unlock file if needed (remove immutable flag)
        try unlockFile(at: url)

        // Strip extended attributes before deletion
        removeExtendedAttributes(at: url)

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

        var attrs = stat()
        guard stat(path, &attrs) == 0 else {
            return  // Can't stat file, proceed anyway
        }

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

    /// Remove all extended attributes from a file.
    /// On macOS, extended attributes (xattrs) and resource forks can contain
    /// sensitive metadata such as where a file was downloaded from, Spotlight
    /// comments, and custom tags. Stripping them before deletion prevents
    /// metadata leakage even if the file's data blocks are recovered.
    private func removeExtendedAttributes(at url: URL) {
        let path = url.path

        // listxattr returns the total buffer size needed for all attribute names
        let size = listxattr(path, nil, 0, XATTR_NOFOLLOW)
        guard size > 0 else { return }

        // Allocate buffer and list all attribute names
        var buffer = [CChar](repeating: 0, count: size)
        let actualSize = listxattr(path, &buffer, size, XATTR_NOFOLLOW)
        guard actualSize > 0 else { return }

        // Parse null-terminated attribute names and remove each one
        var offset = 0
        while offset < actualSize {
            let name = String(cString: &buffer[offset])
            guard !name.isEmpty else { break }

            // removexattr: remove the attribute; ignore errors (may lack permission)
            _ = removexattr(path, name, XATTR_NOFOLLOW)

            offset += name.utf8.count + 1  // +1 for null terminator
        }
    }

    /// Check if a file/directory can be deleted
    /// - Parameter url: URL to check
    /// - Returns: true if deletable
    func isDeletable(at url: URL) -> Bool {
        fileManager.isDeletableFile(atPath: url.path)
    }
}
