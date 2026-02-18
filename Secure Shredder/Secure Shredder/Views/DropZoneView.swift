//
//  DropZoneView.swift
//  SecureShredder
//
//  Drag and drop zone for files
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            if viewModel.selectedFiles.isEmpty {
                // Empty state - show drop zone
                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(isTargeted ? .accentColor : .secondary)

                    Text("Drop files or folders here")
                        .font(.title3)
                        .foregroundColor(.primary)

                    Text("or")
                        .foregroundColor(.secondary)

                    Button("Choose Files") {
                        chooseFiles()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [10])
                        )
                )
            } else {
                // Files selected - show list
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(viewModel.selectedFiles.count) item\(viewModel.selectedFiles.count == 1 ? "" : "s") selected")
                            .font(.headline)

                        Spacer()

                        Text(viewModel.formattedTotalSize)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("Clear") {
                            viewModel.clearFiles()
                        }
                        .buttonStyle(.bordered)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.selectedFiles) { file in
                                FileRowView(file: file) {
                                    viewModel.removeFile(file)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                DispatchQueue.main.async {
                    viewModel.addFiles(urls: [url])
                }
            }
        }
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Select files or folders to securely delete"

        if panel.runModal() == .OK {
            viewModel.addFiles(urls: panel.urls)
        }
    }
}

struct FileRowView: View {
    let file: FileItem
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(file.isDirectory ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.body)

                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    DropZoneView(viewModel: MainViewModel())
        .padding()
        .frame(width: 600, height: 400)
}
