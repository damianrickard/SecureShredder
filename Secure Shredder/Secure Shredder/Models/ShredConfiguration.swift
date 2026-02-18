//
//  ShredConfiguration.swift
//  SecureShredder
//
//  Configuration for secure file shredding operations
//

import Foundation

/// Configuration for a shred operation
struct ShredConfiguration {
    /// Whether to verify the encrypted data was written (crypto-shred)
    /// and verify the final overwrite pass (overwrite)
    let verifyAfterWrite: Bool

    /// Size of chunks to process at a time (in bytes)
    let chunkSize: Int

    /// Number of overwrite passes for DoD 5220.22-M
    /// - 1: Quick single random pass
    /// - 3: Standard DoD (zeros, ones, random)
    /// - 7: Extended DoD (two full cycles + final random)
    let overwritePasses: Int

    /// Default configuration (3-pass DoD standard)
    static let `default` = ShredConfiguration(
        verifyAfterWrite: true,
        chunkSize: 1024 * 1024, // 1MB chunks
        overwritePasses: 3
    )

    /// Quick single-pass configuration
    static let quick = ShredConfiguration(
        verifyAfterWrite: false,
        chunkSize: 1024 * 1024,
        overwritePasses: 1
    )

    /// Extended 7-pass DoD configuration
    static let extended = ShredConfiguration(
        verifyAfterWrite: true,
        chunkSize: 1024 * 1024,
        overwritePasses: 7
    )

    /// Validate configuration parameters
    var isValid: Bool {
        chunkSize > 0 && overwritePasses > 0
    }

    /// Human-readable description of the overwrite method
    var overwriteDescription: String {
        switch overwritePasses {
        case 1:
            return "1 pass (random)"
        case 3:
            return "3 passes (DoD 5220.22-M)"
        case 7:
            return "7 passes (DoD extended)"
        default:
            return "\(overwritePasses) passes"
        }
    }
}
