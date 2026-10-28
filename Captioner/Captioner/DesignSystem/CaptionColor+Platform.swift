// CaptionColor+Platform.swift
// Bridges CaptionerKit's platform-neutral colors to SwiftUI and UIKit.
//
// The live preview uses `Color`; the export renderer uses `UIColor`. Keeping
// both conversions here means the two renderers always agree on color.

import CaptionerKit
import SwiftUI
import UIKit

extension CaptionColor {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
