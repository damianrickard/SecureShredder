//
//  WarningBannerView.swift
//  SecureShredder
//
//  Warning banner about APFS/SSD limitations
//

import SwiftUI

struct WarningBannerView: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text("Important: APFS/SSD Limitations")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("This app provides best-effort secure deletion, but has limitations:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    BulletPoint(text: "APFS uses copy-on-write, preventing true physical overwriting")
                    BulletPoint(text: "SSDs use wear leveling, which may preserve data in hidden areas")
                    BulletPoint(text: "Most effective on non-encrypted external drives")

                    Text("For maximum security on FileVault volumes: delete file + change FileVault password")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    WarningBannerView()
        .padding()
        .frame(width: 500)
}
