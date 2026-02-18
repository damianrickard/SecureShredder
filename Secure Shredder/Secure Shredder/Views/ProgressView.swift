//
//  ProgressView.swift
//  SecureShredder
//
//  Progress view for shredding operations
//

import SwiftUI

struct ShredProgressView: View {
    @ObservedObject var operation: ShredOperation

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            // Title
            Text("Securely Deleting Files")
                .font(.title2)
                .fontWeight(.semibold)

            // Progress info
            VStack(spacing: 12) {
                // Current file
                if !operation.currentFile.isEmpty {
                    VStack(spacing: 4) {
                        Text("Processing:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(operation.currentFile)
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // File count
                if operation.totalFiles > 0 {
                    VStack(alignment: .center, spacing: 4) {
                        Text("Files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(operation.currentFileIndex + 1) of \(operation.totalFiles)")
                            .font(.headline)
                    }
                }

                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: operation.progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(height: 8)

                    // Percentage
                    Text("\(Int(operation.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                }

                // Status message (shows pass info for overwrite operations)
                if !operation.statusMessage.isEmpty {
                    Text(operation.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            // Cancel button
            Button("Cancel") {
                operation.cancel()
            }
            .buttonStyle(.bordered)
            .disabled(!operation.isRunning)
        }
        .padding(32)
        .frame(width: 400)
    }
}

#Preview {
    ShredProgressView(operation: {
        let op = ShredOperation()
        op.isRunning = true
        op.progress = 0.45
        op.currentFile = "document.pdf"
        op.currentFileIndex = 5
        op.totalFiles = 12
        op.statusMessage = "Pass 2/3: ones (0xFF)"
        return op
    }())
}
