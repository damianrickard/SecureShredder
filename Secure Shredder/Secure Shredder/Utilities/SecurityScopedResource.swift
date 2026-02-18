//
//  SecurityScopedResource.swift
//  SecureShredder
//
//  Handles security-scoped resource access for sandboxed apps
//

import Foundation

/// Manages security-scoped resource access
class SecurityScopedResource {
    /// Store bookmark data for a URL to maintain access
    /// - Parameter url: The URL to create a bookmark for
    /// - Returns: Bookmark data if successful
    static func createBookmark(for url: URL) -> Data? {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmarkData
        } catch {
            return nil
        }
    }

    /// Resolve a bookmark to get a URL with security scope
    /// - Parameter bookmarkData: The bookmark data
    /// - Returns: URL if successful
    static func resolveBookmark(_ bookmarkData: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return url
        } catch {
            return nil
        }
    }
}
