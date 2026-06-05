// MiraRailView.swift
// Compact Claude-style navigation rail for Mira's main sections.
//
// The root shell owns the selected section binding. The rail only renders and
// updates navigation state.

import SwiftUI

struct MiraRailView: View {
    @Binding var selectedSection: MiraSection

    var body: some View {
        VStack(spacing: 14) {
            Text("M")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(MiraTheme.accent)
                .frame(width: 42, height: 42)
                .background(MiraTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12))

            ForEach(MiraSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Image(systemName: section.symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selectedSection == section ? MiraTheme.accent : MiraTheme.secondaryText)
                        .frame(width: 42, height: 42)
                        .background(
                            selectedSection == section ? MiraTheme.accent.opacity(0.13) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
            }

            Spacer()
        }
        .padding(.vertical, 18)
        .frame(width: 68)
        .background(MiraTheme.rail)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(MiraTheme.border)
                .frame(width: 1)
        }
    }
}
