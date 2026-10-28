// CaptionStyle.swift
// Platform-neutral description of how captions look.
//
// Styles are plain values so they can be tested here and rendered identically
// by two different renderers in the app: the SwiftUI live preview and the
// UIKit image renderer used for burned-in export. Sizes and positions are
// fractions of the video frame, so the look is independent of resolution.

import Foundation

/// An sRGB color with components in 0...1.
public struct CaptionColor: Hashable, Codable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let white = CaptionColor(red: 1, green: 1, blue: 1)
    public static let black = CaptionColor(red: 0, green: 0, blue: 0)
    public static let yellow = CaptionColor(red: 1, green: 0.85, blue: 0.1)
    public static let green = CaptionColor(red: 0.3, green: 0.95, blue: 0.45)
    public static let translucentBlack = CaptionColor(red: 0, green: 0, blue: 0, alpha: 0.65)
}

public struct CaptionStyle: Hashable, Sendable {
    public var textColor: CaptionColor
    /// Color of the word being spoken. `nil` turns word highlighting off.
    public var highlightColor: CaptionColor?
    /// Rounded box behind the caption. `nil` draws a drop shadow instead.
    public var backgroundColor: CaptionColor?
    public var isUppercased: Bool
    /// Heavy (black) weight when `true`, semibold otherwise.
    public var usesHeavyWeight: Bool
    /// Font size as a fraction of the video's shorter side.
    public var relativeFontSize: Double
    /// Vertical center of the caption as a fraction of the video height,
    /// where 0 is the top edge and 1 the bottom edge.
    public var verticalPosition: Double

    public static let fontSizeRange: ClosedRange<Double> = 0.04...0.1
    public static let verticalPositionRange: ClosedRange<Double> = 0.15...0.9

    public init(
        textColor: CaptionColor,
        highlightColor: CaptionColor?,
        backgroundColor: CaptionColor?,
        isUppercased: Bool,
        usesHeavyWeight: Bool,
        relativeFontSize: Double = 0.065,
        verticalPosition: Double = 0.72
    ) {
        self.textColor = textColor
        self.highlightColor = highlightColor
        self.backgroundColor = backgroundColor
        self.isUppercased = isUppercased
        self.usesHeavyWeight = usesHeavyWeight
        self.relativeFontSize = relativeFontSize
        self.verticalPosition = verticalPosition
    }

    public var highlightsWords: Bool {
        highlightColor != nil
    }

    /// Applies text transforms such as uppercasing.
    public func displayText(_ text: String) -> String {
        isUppercased ? text.uppercased() : text
    }

    /// Font size in the canvas's own units (points for preview, pixels for
    /// export) for a canvas of the given size.
    public func fontSize(canvasWidth: Double, canvasHeight: Double) -> Double {
        relativeFontSize * min(canvasWidth, canvasHeight)
    }

    /// Color for the word at `index` when `highlightedIndex` is being spoken.
    public func color(forWordAt index: Int, highlightedIndex: Int?) -> CaptionColor {
        if let highlightColor, index == highlightedIndex {
            return highlightColor
        }
        return textColor
    }
}

/// Ready-made looks offered in the style picker.
public enum CaptionStylePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case karaoke
    case pop
    case boxed
    case minimal

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .karaoke: "Karaoke"
        case .pop: "Pop"
        case .boxed: "Boxed"
        case .minimal: "Minimal"
        }
    }

    public var style: CaptionStyle {
        switch self {
        case .karaoke:
            CaptionStyle(textColor: .white, highlightColor: .yellow, backgroundColor: nil, isUppercased: true, usesHeavyWeight: true)
        case .pop:
            CaptionStyle(textColor: .white, highlightColor: .green, backgroundColor: nil, isUppercased: false, usesHeavyWeight: true, relativeFontSize: 0.075)
        case .boxed:
            CaptionStyle(textColor: .white, highlightColor: nil, backgroundColor: .translucentBlack, isUppercased: false, usesHeavyWeight: false, relativeFontSize: 0.055)
        case .minimal:
            CaptionStyle(textColor: .white, highlightColor: nil, backgroundColor: nil, isUppercased: false, usesHeavyWeight: false, relativeFontSize: 0.05, verticalPosition: 0.85)
        }
    }

    /// Returns this preset's look while keeping the size and position the
    /// user already dialed in, so switching looks does not move captions.
    public func style(keepingLayoutOf current: CaptionStyle) -> CaptionStyle {
        var next = style
        next.relativeFontSize = current.relativeFontSize
        next.verticalPosition = current.verticalPosition
        return next
    }
}
