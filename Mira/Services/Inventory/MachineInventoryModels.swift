// MachineInventoryModels.swift
// Probe and hydration value models for Mira machine inventory.
//
// Inventory services create these values from user-configured machines and
// read-only endpoint probes. UI state consumes the hydrated snapshot.

import Foundation

struct MachineProbeRequest: Identifiable, Hashable, Sendable {
    let id: UUID
    var machineName: String
    var host: String
    var expectedPorts: [Int]

    init(id: UUID = UUID(), machineName: String, host: String, expectedPorts: [Int]) {
        self.id = id
        self.machineName = machineName
        self.host = host
        self.expectedPorts = expectedPorts
    }
}

struct MachineProbeResult: Identifiable, Hashable, Sendable {
    let id: UUID
    var request: MachineProbeRequest
    var endpointSummaries: [EndpointProbeSummary]
    var diagnostics: [ProbeDiagnostic]

    init(
        id: UUID = UUID(),
        request: MachineProbeRequest,
        endpointSummaries: [EndpointProbeSummary],
        diagnostics: [ProbeDiagnostic]
    ) {
        self.id = id
        self.request = request
        self.endpointSummaries = endpointSummaries
        self.diagnostics = diagnostics
    }
}

struct EndpointProbeSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    var address: EndpointAddress
    var engine: EngineKind
    var health: RouteHealth
    var metadataSummary: String
    var modelSummaries: [EndpointModelSummary]
    var imageInventory: ImageEndpointInventory?
    var comfySummary: ComfyUISystemSummary?

    init(
        id: UUID = UUID(),
        address: EndpointAddress,
        engine: EngineKind,
        health: RouteHealth,
        metadataSummary: String,
        modelSummaries: [EndpointModelSummary] = [],
        imageInventory: ImageEndpointInventory? = nil,
        comfySummary: ComfyUISystemSummary? = nil
    ) {
        self.id = id
        self.address = address
        self.engine = engine
        self.health = health
        self.metadataSummary = metadataSummary
        self.modelSummaries = modelSummaries
        self.imageInventory = imageInventory
        self.comfySummary = comfySummary
    }
}

struct ProbeDiagnostic: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var detail: String
    var severity: DiagnosticSeverity

    init(id: UUID = UUID(), title: String, detail: String, severity: DiagnosticSeverity) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
    }
}
