// RouteModels.swift
// Domain values for machines, endpoints, routes, runs, and route validation.
//
// The target picker, Inspector, and orchestration layer share these models.
// Endpoint services later populate them from user configuration and probes.

import Foundation

enum EngineKind: String, CaseIterable, Identifiable, Hashable {
    case lmStudio
    case automatic1111
    case forge
    case comfyUI
    case cloud
    case modelSource

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lmStudio: "LM Studio"
        case .automatic1111: "A1111"
        case .forge: "Forge"
        case .comfyUI: "ComfyUI"
        case .cloud: "Cloud"
        case .modelSource: "Source"
        }
    }
}

enum RouteCapability: String, CaseIterable, Identifiable, Hashable {
    case text
    case vision
    case image
    case animation
    case video
    case inspect
    case workflow
    case reasoning
    case controlNet
    case lora
    case cloud

    var id: String { rawValue }
}

enum RouteHealth: String, Hashable {
    case ready
    case available
    case busy
    case offline
    case needsKey

    var title: String {
        switch self {
        case .ready: "Ready"
        case .available: "Available"
        case .busy: "Busy"
        case .offline: "Offline"
        case .needsKey: "Needs Key"
        }
    }
}

struct Machine: Identifiable, Hashable {
    let id: UUID
    var name: String
    var hostDescription: String
    var platform: String
    var isUserConfigured: Bool
}

struct EngineEndpoint: Identifiable, Hashable {
    let id: UUID
    var machineID: UUID?
    var engine: EngineKind
    var displayName: String
    var port: Int?
    var health: RouteHealth
    var metadataSummary: String
}

struct SmartRoute: Identifiable, Hashable {
    let id: UUID
    var friendlyName: String
    var userAlias: String?
    var machineID: UUID?
    var endpointID: UUID
    var modelName: String
    var capabilities: Set<RouteCapability>
    var health: RouteHealth
    var isPinned: Bool
    var isRecent: Bool
}

struct InventorySnapshot: Hashable {
    var machines: [Machine]
    var endpoints: [EngineEndpoint]
    var routes: [SmartRoute]
    var capturedAt: Date
}

struct SmartRun: Identifiable, Hashable {
    let id: UUID
    var task: ChatTask
    var routeIDs: [UUID]
    var steps: [RunStep]
    var status: RunStatus
}

struct RunStep: Identifiable, Hashable {
    let id: UUID
    var routeID: UUID
    var title: String
    var canRunInParallel: Bool
    var progress: Double?
}

enum RunStatus: String, Hashable {
    case planned
    case running
    case completed
    case failed
}

struct RunConcurrencyPolicy: Hashable {
    var allowsParallelText: Bool
    var allowsParallelMediaOnSameMachine: Bool

    static let defaultPolicy = RunConcurrencyPolicy(
        allowsParallelText: true,
        allowsParallelMediaOnSameMachine: false
    )
}

enum RouteValidator {
    static func canSend(task: ChatTask, route: SmartRoute?) -> Bool {
        guard let route else { return false }
        switch task {
        case .chat:
            return route.capabilities.contains(.text) && route.health != .offline
        case .createMedia:
            return !route.capabilities.intersection([.image, .animation, .video]).isEmpty
                && route.health != .offline
        case .inspect:
            return route.capabilities.contains(.inspect) && route.health != .offline
        case .workflow:
            return route.capabilities.contains(.workflow) && route.health != .offline
        }
    }
}
