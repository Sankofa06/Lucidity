// MiraComponents.swift
// Shared visual components for Mira cards, chips, and section headers.
//
// Feature views use these pieces to avoid duplicated styling while keeping each
// screen focused on its own content.

import SwiftUI

struct MiraSectionHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(MiraTheme.accent)
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(MiraTheme.text)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(MiraTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MiraCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(MiraTheme.surface, in: RoundedRectangle(cornerRadius: MiraTheme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: MiraTheme.cardRadius)
                    .stroke(MiraTheme.border, lineWidth: 1)
            }
    }
}

struct MiraChip: View {
    let title: String
    var symbolName: String? = nil
    var tint: Color = MiraTheme.info

    var body: some View {
        HStack(spacing: 5) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.caption2.weight(.bold))
            }
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.13), in: Capsule())
    }
}

struct AdvisorChip: View {
    let title: String

    var body: some View {
        Button {
        } label: {
            Label(title, systemImage: "sparkle.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MiraTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(MiraTheme.accent.opacity(0.12), in: Capsule())
                .overlay {
                    Capsule().stroke(MiraTheme.accent.opacity(0.24), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
