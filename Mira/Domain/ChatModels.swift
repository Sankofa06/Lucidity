// ChatModels.swift
// Domain values for Mira chat tasks, sessions, and messages.
//
// Chat views and orchestration tests consume these lightweight values. They do
// not perform persistence or networking.

import Foundation

enum ChatTask: Hashable {
    case chat(ChatMode)
    case createMedia
    case inspect
    case workflow

    var title: String {
        switch self {
        case .chat(let mode): mode.title
        case .createMedia: "Create Media"
        case .inspect: "Inspect"
        case .workflow: "Workflow"
        }
    }

    var symbolName: String {
        switch self {
        case .chat: "text.bubble"
        case .createMedia: "sparkles"
        case .inspect: "waveform.path.ecg"
        case .workflow: "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}

enum ChatMode: String, CaseIterable, Identifiable, Hashable {
    case free
    case group
    case compare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: "Free Chat"
        case .group: "Group Chat"
        case .compare: "Compare"
        }
    }
}

struct ChatSession: Identifiable, Hashable {
    let id: UUID
    var title: String
    var projectID: UUID?
    var task: ChatTask
    var routeIDs: [UUID]
    var updatedAt: Date
}

struct ChatMessage: Identifiable, Hashable {
    enum Role: String {
        case user
        case assistant
        case system
        case diagnostic
    }

    let id: UUID
    var role: Role
    var text: String
    var routeID: UUID?
    var createdAt: Date
}
