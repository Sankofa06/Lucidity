// MiraTheme.swift
// Design tokens for Mira's first-build visual system.
//
// Feature views consume these shared colors and sizing tokens so the interface
// can later support user-selectable themes without duplicated styling.

import SwiftUI

enum MiraTheme {
    static let background = Color(red: 0.070, green: 0.068, blue: 0.063)
    static let rail = Color(red: 0.095, green: 0.091, blue: 0.084)
    static let surface = Color(red: 0.130, green: 0.124, blue: 0.114)
    static let surfaceStrong = Color(red: 0.175, green: 0.164, blue: 0.148)
    static let elevated = Color(red: 0.215, green: 0.200, blue: 0.176)
    static let accent = Color(red: 0.925, green: 0.615, blue: 0.380)
    static let success = Color(red: 0.300, green: 0.835, blue: 0.475)
    static let warning = Color(red: 0.980, green: 0.750, blue: 0.300)
    static let info = Color(red: 0.460, green: 0.720, blue: 0.960)
    static let text = Color(red: 0.940, green: 0.925, blue: 0.895)
    static let secondaryText = Color(red: 0.660, green: 0.635, blue: 0.590)
    static let border = Color.white.opacity(0.075)

    static let cardRadius: CGFloat = 8
    static let controlRadius: CGFloat = 8
    static let glowRadius: CGFloat = 18
}
