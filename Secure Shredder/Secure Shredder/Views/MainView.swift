//
//  MainView.swift
//  SecureShredder
//
//  Main application view
//

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Warning banner
            WarningBannerView()
                .padding(.horizontal)

            // Drop zone
            DropZoneView(viewModel: viewModel)
                .padding(.horizontal)

            Divider()

            // Action button
            HStack {
                Spacer()

                // Shred button
                Button("Shred Files") {
                    viewModel.confirmShred()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(viewModel.selectedFiles.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 600, minHeight: 500)
        .sheet(isPresented: $viewModel.showingConfirmation) {
            ConfirmationView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingProgress) {
            ShredProgressView(operation: viewModel.operation)
                .interactiveDismissDisabled()
        }
        .alert("Shredding Complete", isPresented: $viewModel.showingResult) {
            Button("OK") {
                viewModel.showingResult = false
            }
        } message: {
            if let result = viewModel.lastResult {
                let failedFiles = result.fileResults.filter { !$0.success }
                if failedFiles.isEmpty {
                    Text(result.summary)
                } else {
                    Text("\(result.summary)\n\nFailed files:\n" + failedFiles.map {
                        "\($0.fileName): \($0.error?.localizedDescription ?? "Unknown error")"
                    }.joined(separator: "\n"))
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.showingError = false
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onOpenURL { url in
            handleURLScheme(url)
        }
    }

    /// Handle URL scheme from Quick Action with input validation
    private func handleURLScheme(_ url: URL) {
        guard url.scheme == "secureshredder",
              url.host == "shred" else {
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return
        }

        // Try security-scoped bookmarks first (preferred), then fall back to raw paths
        if let bookmarksParam = queryItems.first(where: { $0.name == "bookmarks" })?.value {
            handleBookmarks(bookmarksParam)
        } else if let filesParam = queryItems.first(where: { $0.name == "files" })?.value {
            handleFilePaths(filesParam)
        }
    }

    /// Resolve security-scoped bookmarks from the quick action extension
    private func handleBookmarks(_ base64Param: String) {
        guard let outerData = Data(base64Encoded: base64Param),
              let base64Strings = try? JSONDecoder().decode([String].self, from: outerData) else {
            return
        }

        var resolvedURLs: [URL] = []

        for base64Bookmark in base64Strings {
            guard let bookmarkData = Data(base64Encoded: base64Bookmark) else { continue }

            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }

            // Start accessing the security-scoped resource
            _ = url.startAccessingSecurityScopedResource()
            resolvedURLs.append(url)
        }

        guard !resolvedURLs.isEmpty else { return }

        viewModel.addFiles(urls: resolvedURLs)
        viewModel.confirmShred()
    }

    /// Handle raw file paths (fallback) with validation
    private func handleFilePaths(_ filesParam: String) {
        guard let base64Data = Data(base64Encoded: filesParam),
              let paths = try? JSONDecoder().decode([String].self, from: base64Data) else {
            return
        }

        let fileManager = FileManager.default
        let validURLs = paths.compactMap { path -> URL? in
            let url = URL(fileURLWithPath: path)

            // Reject non-absolute paths
            guard path.hasPrefix("/") else { return nil }

            // Reject paths containing traversal sequences
            let normalized = (path as NSString).standardizingPath
            guard normalized == path || URL(fileURLWithPath: normalized).standardizedFileURL == url.standardizedFileURL else {
                return nil
            }

            // Verify file actually exists
            guard fileManager.fileExists(atPath: url.path) else { return nil }

            // Reject symbolic links at the top level
            if let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
               values.isSymbolicLink == true {
                return nil
            }

            return url
        }

        guard !validURLs.isEmpty else { return }

        viewModel.addFiles(urls: validURLs)
        viewModel.confirmShred()
    }
}

#Preview {
    MainView()
        .frame(width: 700, height: 600)
}
