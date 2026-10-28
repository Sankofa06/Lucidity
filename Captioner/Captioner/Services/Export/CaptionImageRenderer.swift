// CaptionImageRenderer.swift
// Draws one caption frame into a bitmap for burned-in export.
//
// Mirrors `CaptionOverlayView`'s look in UIKit: same font weights, colors,
// uppercasing, rounded box or drop shadow, centered wrapping, and the same
// padding ratios. `CaptionOverlayBuilder` calls this once per caption frame.
// Main-actor isolated because it uses UIKit text drawing.

import CaptionerKit
import UIKit

@MainActor
enum CaptionImageRenderer {
    /// Fraction of the canvas width a caption may occupy before wrapping.
    /// Shared with the preview overlay.
    static let maxWidthFraction: CGFloat = 0.86

    /// Renders `words` with the word at `highlightedIndex` highlighted.
    /// `fontSize` and `maxWidth` are in output pixels.
    static func image(
        words: [String],
        highlightedIndex: Int?,
        style: CaptionStyle,
        fontSize: CGFloat,
        maxWidth: CGFloat
    ) -> CGImage? {
        let text = attributedText(words: words, highlightedIndex: highlightedIndex, style: style, fontSize: fontSize)
        let padding = CaptionMetrics.padding(fontSize: fontSize, style: style)
        let textBounds = text.boundingRect(
            with: CGSize(width: max(1, maxWidth - 2 * padding), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        let size = CGSize(width: textBounds.width + 2 * padding, height: textBounds.height + 2 * padding)
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // The canvas is already in video pixels.
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            if let background = style.backgroundColor {
                background.uiColor.setFill()
                UIBezierPath(
                    roundedRect: CGRect(origin: .zero, size: size),
                    cornerRadius: CaptionMetrics.cornerRadius(fontSize: fontSize)
                ).fill()
            }
            text.draw(
                with: CGRect(x: padding, y: padding, width: textBounds.width, height: textBounds.height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
        }
        return image.cgImage
    }

    private static func attributedText(
        words: [String],
        highlightedIndex: Int?,
        style: CaptionStyle,
        fontSize: CGFloat
    ) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize, weight: style.usesHeavyWeight ? .heavy : .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        var baseAttributes: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: paragraph]
        if style.backgroundColor == nil {
            // Without a box, a soft shadow keeps text legible on bright video.
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(CaptionMetrics.shadowOpacity)
            shadow.shadowBlurRadius = CaptionMetrics.shadowRadius(fontSize: fontSize)
            shadow.shadowOffset = CGSize(width: 0, height: CaptionMetrics.shadowOffset(fontSize: fontSize))
            baseAttributes[.shadow] = shadow
        }

        let text = NSMutableAttributedString()
        for (index, word) in words.enumerated() {
            var attributes = baseAttributes
            attributes[.foregroundColor] = style.color(forWordAt: index, highlightedIndex: highlightedIndex).uiColor
            let separator = index < words.count - 1 ? " " : ""
            text.append(NSAttributedString(string: style.displayText(word) + separator, attributes: attributes))
        }
        return text
    }
}
