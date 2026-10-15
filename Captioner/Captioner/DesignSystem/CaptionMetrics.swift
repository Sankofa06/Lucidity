// CaptionMetrics.swift
// Size ratios shared by the caption preview and the export renderer.
//
// Every value scales with font size so captions look the same at any
// resolution. `CaptionOverlayView` (points) and `CaptionImageRenderer`
// (pixels) both read these, which keeps preview and export in sync.

import CaptionerKit
import CoreGraphics

enum CaptionMetrics {
    static let shadowOpacity: CGFloat = 0.85

    static func padding(fontSize: CGFloat, style: CaptionStyle) -> CGFloat {
        fontSize * (style.backgroundColor == nil ? 0.2 : 0.35)
    }

    static func cornerRadius(fontSize: CGFloat) -> CGFloat {
        fontSize * 0.25
    }

    static func shadowRadius(fontSize: CGFloat) -> CGFloat {
        fontSize * 0.12
    }

    static func shadowOffset(fontSize: CGFloat) -> CGFloat {
        fontSize * 0.04
    }
}
