// CaptionOverlayView.swift
// Live caption preview drawn over the playing video.
//
// Renders the active cue with the selected style, highlighting the word being
// spoken. It must be laid out in a frame matching the video's aspect ratio so
// fractions of the canvas match the export. Sizes come from `CaptionMetrics`
// and `CaptionImageRenderer`, the same values the exporter uses.

import CaptionerKit
import SwiftUI

struct CaptionOverlayView: View {
    let cue: CaptionCue?
    let highlightedWordIndex: Int?
    let style: CaptionStyle

    var body: some View {
        GeometryReader { geometry in
            if let cue {
                let size = geometry.size
                let fontSize = CGFloat(style.fontSize(canvasWidth: size.width, canvasHeight: size.height))
                captionText(for: cue, fontSize: fontSize)
                    .frame(maxWidth: size.width * CaptionImageRenderer.maxWidthFraction)
                    .position(x: size.width / 2, y: size.height * CGFloat(style.verticalPosition))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func captionText(for cue: CaptionCue, fontSize: CGFloat) -> some View {
        Text(attributedText(for: cue))
            .font(.system(size: fontSize, weight: style.usesHeavyWeight ? .heavy : .semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .shadow(
                color: .black.opacity(style.backgroundColor == nil ? CaptionMetrics.shadowOpacity : 0),
                radius: CaptionMetrics.shadowRadius(fontSize: fontSize),
                y: CaptionMetrics.shadowOffset(fontSize: fontSize)
            )
            .padding(CaptionMetrics.padding(fontSize: fontSize, style: style))
            .background {
                if let background = style.backgroundColor {
                    RoundedRectangle(cornerRadius: CaptionMetrics.cornerRadius(fontSize: fontSize))
                        .fill(background.swiftUIColor)
                }
            }
    }

    private func attributedText(for cue: CaptionCue) -> AttributedString {
        var text = AttributedString()
        for (index, word) in cue.words.enumerated() {
            let separator = index < cue.words.count - 1 ? " " : ""
            var piece = AttributedString(style.displayText(word.text) + separator)
            piece.foregroundColor = style.color(forWordAt: index, highlightedIndex: highlightedWordIndex).swiftUIColor
            text.append(piece)
        }
        return text
    }
}
