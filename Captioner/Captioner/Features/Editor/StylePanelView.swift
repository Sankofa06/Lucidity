// StylePanelView.swift
// Caption look controls: style presets plus size and position sliders.
//
// Presentation only. Preset taps call `EditorViewModel.selectPreset(_:)`;
// sliders bind directly to `viewModel.style`.

import CaptionerKit
import SwiftUI

struct StylePanelView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CaptionStylePreset.allCases) { preset in
                            presetButton(preset)
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Size").font(.subheadline.weight(.semibold))
                    Slider(value: $viewModel.style.relativeFontSize, in: CaptionStyle.fontSizeRange)
                        .accessibilityLabel("Caption size")
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Position").font(.subheadline.weight(.semibold))
                    Slider(value: $viewModel.style.verticalPosition, in: CaptionStyle.verticalPositionRange) {
                        Text("Caption position")
                    } minimumValueLabel: {
                        Image(systemName: "arrow.up.to.line")
                    } maximumValueLabel: {
                        Image(systemName: "arrow.down.to.line")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 4)
        }
    }

    private func presetButton(_ preset: CaptionStylePreset) -> some View {
        let isSelected = viewModel.preset == preset
        let look = preset.style
        return Button {
            viewModel.selectPreset(preset)
        } label: {
            VStack(spacing: 6) {
                Text(look.displayText("Aa"))
                    .font(.system(size: 22, weight: look.usesHeavyWeight ? .heavy : .semibold))
                    .foregroundStyle((look.highlightColor ?? look.textColor).swiftUIColor)
                    .frame(width: 64, height: 44)
                    .background((look.backgroundColor ?? .black).swiftUIColor, in: RoundedRectangle(cornerRadius: 8))
                Text(preset.displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(6)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
