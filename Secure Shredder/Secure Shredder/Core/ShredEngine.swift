//
//  ShredEngine.swift
//  SecureShredder
//
//  Main orchestrator for secure file shredding operations
//

import Foundation
import Combine

/// Main engine for orchestrating secure file shredding
@MainActor
class ShredEngine: ObservableObject {
    private let cryptoShredder = CryptoShredder()
    private let fileDiscovery = FileDiscovery()
    private let secureDeletion = SecureDeletion()
    private let filesystemDetector = FilesystemDetector()
    private let overwriteShredder = OverwriteShredder()

    private enum EraseStrategy {
        case crypto
        case overwrite
        case unlinkOnlyNetwork
    }

    /// Shred files with the given configuration
    /// - Parameters:
    ///   - urls: URLs of files/folders to shred
    ///   - configuration: Shred configuration
    ///   - operation: Operation object for progress tracking
    /// - Returns: ShredResult with operation results
    func shred(
        urls: [URL],
        configuration: ShredConfiguration,
        operation: ShredOperation
    ) async throws -> ShredResult {
        guard configuration.isValid else {
            throw ShredError.invalidConfiguration
        }

        let startTime = Date()
        operation.isRunning = true
        operation.isCancelled = false

        defer {
            operation.isRunning = false
        }

        // Phase 1: Discover all files
        operation.statusMessage = "Discovering files..."
        let discoveredFiles: [FileDiscovery.DiscoveredFile]

        do {
            discoveredFiles = try fileDiscovery.discoverFiles(in: urls)
        } catch {
            throw error
        }

        guard !discoveredFiles.isEmpty else {
            return ShredResult(
                filesProcessed: 0,
                filesSucceeded: 0,
                filesFailed: 0,
                bytesShredded: 0,
                fileResults: [],
                wasCancelled: false,
                duration: Date().timeIntervalSince(startTime)
            )
        }

        operation.totalFiles = discoveredFiles.count

        // Compute per-file erase strategies
        let strategies: [URL: EraseStrategy] = Dictionary(
            uniqueKeysWithValues: discoveredFiles.map { file in
                (file.url, strategy(for: file.url))
            }
        )

        // Phase 2: Process each file according to its strategy
        var fileResults: [ShredResult.FileResult] = []
        var bytesShredded: Int64 = 0
        var filesSucceeded = 0
        var filesFailed = 0

        for (index, file) in discoveredFiles.enumerated() {
            // Check for cancellation
            if operation.isCancelled || Task.isCancelled {
                operation.statusMessage = "Cancelled"
                return ShredResult(
                    filesProcessed: index,
                    filesSucceeded: filesSucceeded,
                    filesFailed: filesFailed,
                    bytesShredded: bytesShredded,
                    fileResults: fileResults,
                    wasCancelled: true,
                    duration: Date().timeIntervalSince(startTime)
                )
            }

            operation.currentFileIndex = index
            operation.currentFile = file.url.lastPathComponent

            let strategy = strategies[file.url] ?? .overwrite

            // Process the file with the appropriate strategy
            let fileResult = await processSingleFile(
                file: file,
                strategy: strategy,
                configuration: configuration,
                fileIndex: index,
                totalFiles: discoveredFiles.count,
                operation: operation
            )

            fileResults.append(fileResult)

            if fileResult.success {
                filesSucceeded += 1
                bytesShredded += fileResult.bytesWritten
            } else {
                filesFailed += 1
            }

            // Update overall progress
            let fileProgress = Double(index + 1) / Double(discoveredFiles.count)
            operation.progress = fileProgress
        }

        // Phase 3: Delete empty directories if any
        operation.statusMessage = "Cleaning up directories..."
        for url in urls {
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues?.isDirectory == true {
                try? secureDeletion.deleteDirectory(at: url)
            }
        }

        operation.statusMessage = "Complete"
        operation.progress = 1.0

        return ShredResult(
            filesProcessed: discoveredFiles.count,
            filesSucceeded: filesSucceeded,
            filesFailed: filesFailed,
            bytesShredded: bytesShredded,
            fileResults: fileResults,
            wasCancelled: false,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    private func strategy(for url: URL) -> EraseStrategy {
        let info = filesystemDetector.getVolumeInfo(for: url)

        if info.isNetwork {
            return .unlinkOnlyNetwork
        }

        switch info.filesystemType {
        case .apfs, .zfs, .btrfs:
            return .crypto
        default:
            return .overwrite
        }
    }

    private func processSingleFile(
        file: FileDiscovery.DiscoveredFile,
        strategy: EraseStrategy,
        configuration: ShredConfiguration,
        fileIndex: Int,
        totalFiles: Int,
        operation: ShredOperation
    ) async -> ShredResult.FileResult {
        let startBytes = file.size

        switch strategy {
        case .crypto:
            do {
                try await cryptoShredder.shredFile(
                    at: file.url,
                    chunkSize: configuration.chunkSize,
                    verify: configuration.verifyAfterWrite
                ) { progress, status in
                    Task { @MainActor in
                        if !status.isEmpty {
                            operation.statusMessage = status
                        }

                        let fileWeight = 1.0 / Double(totalFiles)
                        let fileProgress = Double(fileIndex) * fileWeight
                        let currentFileProgress = progress * fileWeight
                        operation.progress = fileProgress + currentFileProgress
                    }
                }

                try secureDeletion.deleteFile(at: file.url)

                return ShredResult.FileResult(
                    url: file.url,
                    success: true,
                    error: nil,
                    bytesWritten: startBytes
                )
            } catch {
                return ShredResult.FileResult(
                    url: file.url,
                    success: false,
                    error: error,
                    bytesWritten: 0
                )
            }

        case .overwrite:
            do {
                try await overwriteShredder.overwriteFile(
                    at: file.url,
                    passes: configuration.overwritePasses,
                    chunkSize: configuration.chunkSize,
                    verify: configuration.verifyAfterWrite
                ) { progress, status in
                    Task { @MainActor in
                        if !status.isEmpty {
                            operation.statusMessage = status
                        }

                        let fileWeight = 1.0 / Double(totalFiles)
                        let fileProgress = Double(fileIndex) * fileWeight
                        let currentFileProgress = progress * fileWeight
                        operation.progress = fileProgress + currentFileProgress
                    }
                }

                try secureDeletion.deleteFile(at: file.url)

                return ShredResult.FileResult(
                    url: file.url,
                    success: true,
                    error: nil,
                    bytesWritten: startBytes
                )
            } catch {
                return ShredResult.FileResult(
                    url: file.url,
                    success: false,
                    error: error,
                    bytesWritten: 0
                )
            }

        case .unlinkOnlyNetwork:
            do {
                try FileManager.default.removeItem(at: file.url)
                return ShredResult.FileResult(
                    url: file.url,
                    success: true,
                    error: nil,
                    bytesWritten: 0
                )
            } catch {
                return ShredResult.FileResult(
                    url: file.url,
                    success: false,
                    error: error,
                    bytesWritten: 0
                )
            }
        }
    }
}
