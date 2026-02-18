//
//  ActionRequestHandler.swift
//  ShredderQuickAction
//
//  Finder Quick Action extension handler
//
//  Uses security-scoped bookmarks to safely pass file references
//  from the extension to the main app, preserving sandbox access.
//

import Foundation
import AppKit

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        // Extract file URLs from the extension context
        guard let items = context.inputItems as? [NSExtensionItem] else {
            context.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        // Count total number of attachments to process
        var totalAttachments = 0
        for item in items {
            totalAttachments += item.attachments?.count ?? 0
        }

        guard totalAttachments > 0 else {
            context.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        // Thread-safe collection of URLs
        let group = DispatchGroup()
        let urlQueue = DispatchQueue(label: "com.secureshredder.urlcollection")
        var fileURLs: [URL] = []

        for item in items {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier("public.file-url") {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, error in
                        if let url = data as? URL {
                            urlQueue.sync {
                                fileURLs.append(url)
                            }
                        }
                        group.leave()
                    }
                }
            }
        }

        // Wait for all loads to complete, then launch main app
        group.notify(queue: .main) {
            if !fileURLs.isEmpty {
                self.launchMainApp(with: fileURLs, context: context)
            } else {
                context.completeRequest(returningItems: nil, completionHandler: nil)
            }
        }
    }

    private func launchMainApp(with urls: [URL], context: NSExtensionContext) {
        // Create security-scoped bookmarks for each URL so the main app can access them
        var bookmarkDataArray: [Data] = []

        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                bookmarkDataArray.append(bookmarkData)
            } catch {
                // Fall back to raw path if bookmark creation fails
            }
        }

        // If we got bookmarks, encode them; otherwise fall back to path-based encoding
        let urlScheme: String

        if !bookmarkDataArray.isEmpty {
            // Encode bookmarks as base64 JSON array of base64 bookmark data
            let base64Bookmarks = bookmarkDataArray.map { $0.base64EncodedString() }
            guard let jsonData = try? JSONEncoder().encode(base64Bookmarks),
                  let base64 = jsonData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                context.completeRequest(returningItems: nil, completionHandler: nil)
                return
            }
            urlScheme = "secureshredder://shred?bookmarks=\(base64)"
        } else {
            // Fallback: encode file paths (less secure but functional)
            let urlStrings = urls.map { $0.path }
            guard let jsonData = try? JSONEncoder().encode(urlStrings),
                  let base64 = jsonData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                context.completeRequest(returningItems: nil, completionHandler: nil)
                return
            }
            urlScheme = "secureshredder://shred?files=\(base64)"
        }

        guard let url = URL(string: urlScheme) else {
            context.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        NSWorkspace.shared.open(url)
        context.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
