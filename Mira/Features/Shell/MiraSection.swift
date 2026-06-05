// MiraSection.swift
// Navigation sections available from Mira's compact rail.
//
// The shell uses these cases to keep navigation shallow and consistent across
// iPhone, iPad, and future Mac-width layouts.

import Foundation

enum MiraSection: String, CaseIterable, Identifiable {
    case chat
    case projects
    case personas
    case teams
    case library
    case sources
    case machines
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: "Chat"
        case .projects: "Projects"
        case .personas: "Personas"
        case .teams: "Teams"
        case .library: "Library"
        case .sources: "Sources"
        case .machines: "Machines"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .chat: "text.bubble"
        case .projects: "folder"
        case .personas: "person.crop.circle"
        case .teams: "person.3"
        case .library: "books.vertical"
        case .sources: "square.and.arrow.down"
        case .machines: "desktopcomputer"
        case .settings: "gearshape"
        }
    }
}
