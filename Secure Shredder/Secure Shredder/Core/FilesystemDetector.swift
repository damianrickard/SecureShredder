//
//  FilesystemDetector.swift
//  SecureShredder
//
//  Detects filesystem type and volume information for security guidance
//

import Foundation

/// Information about a volume's filesystem
struct VolumeInfo: Equatable {
    let filesystemType: FilesystemType
    let volumeName: String
    let isNetwork: Bool
    let isRemovable: Bool
    let mountPoint: String

    var securityNote: String {
        if isNetwork {
            return "Network volume - server may retain copies"
        }
        switch filesystemType {
        case .apfs, .zfs, .btrfs:
            return "Copy-on-write filesystem - crypto-shred recommended"
        case .hfsPlus, .exfat, .fat32, .ntfs, .ext4:
            return "Traditional filesystem - direct overwrite"
        case .unknown:
            return "Unknown filesystem"
        }
    }

    var isCoW: Bool {
        switch filesystemType {
        case .apfs, .zfs, .btrfs:
            return true
        default:
            return false
        }
    }
}

/// Known filesystem types
enum FilesystemType: String {
    case apfs = "apfs"
    case hfsPlus = "hfs"
    case exfat = "exfat"
    case fat32 = "msdos"
    case ntfs = "ntfs"
    case ext4 = "ext4"
    case zfs = "zfs"
    case btrfs = "btrfs"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .apfs: return "APFS"
        case .hfsPlus: return "HFS+ (Mac OS Extended)"
        case .exfat: return "exFAT"
        case .fat32: return "FAT32"
        case .ntfs: return "NTFS"
        case .ext4: return "ext4"
        case .zfs: return "ZFS"
        case .btrfs: return "Btrfs"
        case .unknown: return "Unknown"
        }
    }
}

/// Detects filesystem information for files and volumes
class FilesystemDetector {

    /// Get volume info for a file URL
    func getVolumeInfo(for url: URL) -> VolumeInfo {
        let resourceKeys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeIsRemovableKey,
            .volumeIsLocalKey,
            .volumeLocalizedFormatDescriptionKey
        ]

        var volumeName = "Unknown"
        var isRemovable = false
        var isNetwork = false
        var filesystemType = FilesystemType.unknown
        var mountPoint = "/"

        // Get volume URL
        if let volumeURL = getVolumeURL(for: url) {
            mountPoint = volumeURL.path

            // Get resource values
            if let values = try? volumeURL.resourceValues(forKeys: resourceKeys) {
                volumeName = values.volumeName ?? "Unknown"
                isRemovable = values.volumeIsRemovable ?? false
                isNetwork = !(values.volumeIsLocal ?? true)
            }

            // Detect filesystem type using statfs
            filesystemType = detectFilesystemType(at: volumeURL.path)
        }

        return VolumeInfo(
            filesystemType: filesystemType,
            volumeName: volumeName,
            isNetwork: isNetwork,
            isRemovable: isRemovable,
            mountPoint: mountPoint
        )
    }

    /// Analyze multiple URLs and return unique volume infos
    func analyzeVolumes(for urls: [URL]) -> [VolumeInfo] {
        var seen = Set<String>()
        var volumes: [VolumeInfo] = []

        for url in urls {
            let info = getVolumeInfo(for: url)
            if !seen.contains(info.mountPoint) {
                seen.insert(info.mountPoint)
                volumes.append(info)
            }
        }

        return volumes
    }

    /// Check if any URLs are on network volumes
    func hasNetworkVolumes(urls: [URL]) -> Bool {
        for url in urls {
            let info = getVolumeInfo(for: url)
            if info.isNetwork {
                return true
            }
        }
        return false
    }

    /// Get the volume URL for a file
    private func getVolumeURL(for url: URL) -> URL? {
        var volumeURL: URL?
        do {
            let values = try url.resourceValues(forKeys: [.volumeURLKey])
            volumeURL = values.volume
        } catch {
            // Fall back to finding mount point
            volumeURL = findMountPoint(for: url)
        }
        return volumeURL
    }

    /// Find mount point by walking up the path
    private func findMountPoint(for url: URL) -> URL? {
        var current = url.standardizedFileURL
        var lastDevice: dev_t = 0

        var stat_buf = stat()
        if stat(current.path, &stat_buf) == 0 {
            lastDevice = stat_buf.st_dev
        }

        while current.path != "/" {
            let parent = current.deletingLastPathComponent()
            if stat(parent.path, &stat_buf) == 0 {
                if stat_buf.st_dev != lastDevice {
                    return current
                }
            }
            current = parent
        }

        return URL(fileURLWithPath: "/")
    }

    /// Detect filesystem type using statfs
    private func detectFilesystemType(at path: String) -> FilesystemType {
        var stat_buf = statfs()

        guard statfs(path, &stat_buf) == 0 else {
            return .unknown
        }

        // Convert f_fstypename to String
        let fsTypeName = withUnsafePointer(to: stat_buf.f_fstypename) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) { cstr in
                String(cString: cstr)
            }
        }

        let lowercased = fsTypeName.lowercased()

        // Match known filesystem types
        if lowercased.contains("apfs") {
            return .apfs
        } else if lowercased.contains("hfs") {
            return .hfsPlus
        } else if lowercased.contains("exfat") {
            return .exfat
        } else if lowercased.contains("msdos") || lowercased.contains("fat") {
            return .fat32
        } else if lowercased.contains("ntfs") {
            return .ntfs
        } else if lowercased.contains("ext") {
            return .ext4
        } else if lowercased.contains("zfs") {
            return .zfs
        } else if lowercased.contains("btrfs") {
            return .btrfs
        } else if lowercased.contains("smbfs") || lowercased.contains("nfs") ||
                  lowercased.contains("afpfs") || lowercased.contains("webdav") {
            // Network filesystems - mark as unknown type but isNetwork will be true
            return .unknown
        }

        return .unknown
    }
}
