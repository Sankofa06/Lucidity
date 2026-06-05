// MiraResponsiveLayout.swift
// Width-based layout decisions for Mira's responsive shell.
//
// Root and feature views use this helper to collapse wide studio layouts into
// iPhone-friendly single-column presentations.

import Foundation

struct MiraResponsiveLayout {
    let width: CGFloat

    var showsRailInline: Bool { width >= 760 }
    var showsInspectorInline: Bool { width >= 980 }

    var inspectorWidth: CGFloat {
        min(390, max(330, width * 0.32))
    }
}
