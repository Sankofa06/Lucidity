// WorkspaceModels.swift
// Domain values for projects, personas, teams, workflows, settings, and sources.
//
// Hub views render these values while later persistence and services can map
// them to durable storage.

import Foundation

struct MiraProject: Identifiable, Hashable {
    let id: UUID
    var name: String
    var summary: String
    var sessionCount: Int
}

struct Persona: Identifiable, Hashable {
    let id: UUID
    var name: String
    var role: String
    var character: String?
    var routeID: UUID?
    var mediaEnabled: Bool
    var memoryEnabled: Bool
    var webSearchEnabled: Bool
}

struct Team: Identifiable, Hashable {
    let id: UUID
    var name: String
    var purpose: String
    var personaIDs: [UUID]
}

struct Workflow: Identifiable, Hashable {
    let id: UUID
    var name: String
    var summary: String
    var routeIDs: [UUID]
}

enum ModelSourceKind: String, CaseIterable, Identifiable, Hashable {
    case huggingFace
    case civitAI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .huggingFace: "Hugging Face"
        case .civitAI: "CivitAI"
        }
    }
}

struct ModelSource: Identifiable, Hashable {
    let id: UUID
    var kind: ModelSourceKind
    var isKeyConfigured: Bool
    var summary: String
}

struct AdvisorConfiguration: Hashable {
    var defaultModelName: String
    var requiresConfirmation: Bool
    var trustedModeEnabled: Bool
}

struct DiagnosticEvent: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var severity: DiagnosticSeverity
    var progress: Double?
}

enum DiagnosticSeverity: String, Hashable {
    case info
    case success
    case warning
}
