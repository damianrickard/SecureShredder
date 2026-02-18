//
//  MainViewModel.swift
//  SecureShredder
//
//  Main view model for the app
//

import Foundation
import SwiftUI
import Combine

/// Main view model managing app state
@MainActor
class MainViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Selected files to shred
    @Published var selectedFiles: [FileItem] = []

    /// Whether confirmation sheet is shown
    @Published var showingConfirmation = false

    /// Whether progress view is shown
    @Published var showingProgress = false

    /// Current operation
    @Published var operation = ShredOperation()

    /// Last result
    @Published var lastResult: ShredResult?

    /// Whether to show result alert
    @Published var showingResult = false

    /// Error to display
    @Published var errorMessage: String?

    /// Whether to show error alert
    @Published var showingError = false

    /// Number of overwrite passes (user-selectable)
    @Published var overwritePasses: Int = 3

    // MARK: - Dependencies

    private let shredEngine = ShredEngine()
    private let filesystemDetector = FilesystemDetector()

    // MARK: - Computed Properties

    /// Volume information for selected files
    var volumeInfos: [VolumeInfo] {
        let urls = selectedFiles.map { $0.url }
        return filesystemDetector.analyzeVolumes(for: urls)
    }

    /// Whether any files are on network volumes
    var hasNetworkFiles: Bool {
        volumeInfos.contains { $0.isNetwork }
    }

    var totalSize: Int64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    /// Current shred configuration based on user selections
    var configuration: ShredConfiguration {
        ShredConfiguration(
            verifyAfterWrite: true,
            chunkSize: 1024 * 1024,
            overwritePasses: overwritePasses
        )
    }

    // MARK: - Methods

    /// Add files from URLs
    func addFiles(urls: [URL]) {
        var newFiles: [FileItem] = []

        for url in urls {
            // Check if already added
            if selectedFiles.contains(where: { $0.url == url }) {
                continue
            }

            do {
                let fileItem = try FileItem(url: url)
                newFiles.append(fileItem)
            } catch {
                showError("Failed to add \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        selectedFiles.append(contentsOf: newFiles)
    }

    /// Remove a file from the selection
    func removeFile(_ file: FileItem) {
        selectedFiles.removeAll { $0.id == file.id }
    }

    /// Clear all selected files
    func clearFiles() {
        selectedFiles.removeAll()
    }

    /// Show confirmation dialog
    func confirmShred() {
        guard !selectedFiles.isEmpty else {
            showError("No files selected")
            return
        }

        showingConfirmation = true
    }

    /// Start shredding operation
    func startShredding() {
        showingConfirmation = false
        showingProgress = true

        let urls = selectedFiles.map { $0.url }
        let config = configuration

        operation.reset()

        let task = Task {
            do {
                let result = try await shredEngine.shred(
                    urls: urls,
                    configuration: config,
                    operation: operation
                )

                await MainActor.run {
                    self.lastResult = result
                    self.showingProgress = false
                    self.showingResult = true
                    self.selectedFiles.removeAll()
                }
            } catch {
                await MainActor.run {
                    self.showingProgress = false

                    if Task.isCancelled {
                        self.showError("Operation cancelled")
                    } else if let shredError = error as? ShredError, case .cancelled = shredError {
                        self.showError("Operation cancelled")
                    } else {
                        self.showError(error.localizedDescription)
                    }
                }
            }
        }

        operation.task = task
    }

    /// Cancel current operation
    func cancelShredding() {
        operation.cancel()
    }

    /// Show error message
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
