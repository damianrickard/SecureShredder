//
//  ConfirmationView.swift
//  SecureShredder
//
//  Confirmation dialog before shredding
//

import SwiftUI

struct ConfirmationView: View {
    @ObservedObject var viewModel: MainViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            // Title
            Text("Confirm Secure Deletion")
                .font(.title)
                .fontWeight(.bold)

            // Warning message
            Text("This will permanently delete the following items. This action cannot be undone.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            // Network warning if applicable
            if viewModel.hasNetworkFiles {
                NetworkWarningView()
            }

            Divider()

            // File list summary
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Items to delete:")
                        .font(.headline)

                    Spacer()

                    Text("\(viewModel.selectedFiles.count) item\(viewModel.selectedFiles.count == 1 ? "" : "s")")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Total size:")
                        .font(.headline)

                    Spacer()

                    Text(viewModel.formattedTotalSize)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Method:")
                        .font(.headline)

                    Spacer()

                    Text(methodSummary(for: viewModel.volumeInfos))
                        .foregroundColor(.secondary)
                }

                // Overwrite pass count selector (only shown if overwrite strategy is used)
                if volumeUsesOverwrite(viewModel.volumeInfos) {
                    HStack {
                        Text("Overwrite passes:")
                            .font(.headline)

                        Spacer()

                        Picker("", selection: $viewModel.overwritePasses) {
                            Text("1 (Quick)").tag(1)
                            Text("3 (DoD Standard)").tag(3)
                            Text("7 (DoD Extended)").tag(7)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                    }

                    Text(viewModel.configuration.overwriteDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // Volume information
            VolumeInfoSection(volumeInfos: viewModel.volumeInfos)

            // Crypto-shred explanation
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.blue)
                Text("Files will be encrypted with a random key that is immediately destroyed, making recovery impossible.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // APFS snapshot note (show if any CoW filesystem)
            if viewModel.volumeInfos.contains(where: { $0.isCoW }) {
                APFSSnapshotNoteView()
            }

            // File list preview (max 5)
            if viewModel.selectedFiles.count <= 5 {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.selectedFiles.prefix(5)) { file in
                        HStack {
                            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                                .foregroundColor(.secondary)
                            Text(file.displayName)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(6)
            } else {
                Text("+ \(viewModel.selectedFiles.count - 3) more items...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Delete Permanently") {
                    dismiss()
                    viewModel.startShredding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

/// Informational note about APFS snapshots
struct APFSSnapshotNoteView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .font(.caption)

            Text("Note: Time Machine and local APFS snapshots may retain copies of files until snapshots are deleted.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

/// Warning banner for network volumes
struct NetworkWarningView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Network Volume Detected")
                    .font(.headline)
                    .foregroundColor(.orange)

                Text("Files on network volumes may be retained by the server through caching, snapshots, or backups. Secure deletion cannot be guaranteed for remote storage.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Shows filesystem information for volumes
struct VolumeInfoSection: View {
    let volumeInfos: [VolumeInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Storage Details")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            ForEach(volumeInfos, id: \.mountPoint) { info in
                VolumeInfoRow(info: info)
            }
        }
        .padding(.horizontal)
    }
}

/// Single row showing volume info
struct VolumeInfoRow: View {
    let info: VolumeInfo

    var icon: String {
        if info.isNetwork {
            return "network"
        } else if info.isRemovable {
            return "externaldrive.fill"
        } else {
            return "internaldrive.fill"
        }
    }

    var iconColor: Color {
        if info.isNetwork {
            return .orange
        } else if info.isCoW {
            return .blue
        } else {
            return .green
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(info.volumeName)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text("(\(info.filesystemType.displayName))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if info.isNetwork {
                        Text("NETWORK")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange)
                            .cornerRadius(3)
                    }
                }

                Text(info.securityNote)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

extension ConfirmationView {
    private func methodSummary(for volumeInfos: [VolumeInfo]) -> String {
        let hasNetwork = volumeInfos.contains { $0.isNetwork }
        let hasCoW = volumeInfos.contains { $0.isCoW }
        let hasTraditional = volumeInfos.contains { !$0.isCoW && !$0.isNetwork }

        var methods: [String] = []

        if hasCoW {
            methods.append("Crypto-shred")
        }
        if hasTraditional {
            methods.append("Overwrite")
        }
        if hasNetwork {
            methods.append("Delete only")
        }

        if methods.isEmpty {
            return "Crypto-shred (AES-256)"
        } else if methods.count == 1 {
            if hasNetwork {
                return "Delete only (network) - not guaranteed"
            } else if hasCoW {
                return "Crypto-shred (AES-256)"
            } else {
                return "In-place overwrite"
            }
        } else {
            return "Mixed: " + methods.joined(separator: " + ")
        }
    }

    /// Check if any volume in the list uses the overwrite strategy
    private func volumeUsesOverwrite(_ volumeInfos: [VolumeInfo]) -> Bool {
        volumeInfos.contains { !$0.isCoW && !$0.isNetwork }
    }
}

#Preview {
    ConfirmationView(viewModel: MainViewModel())
}
