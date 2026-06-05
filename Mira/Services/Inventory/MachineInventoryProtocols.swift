// MachineInventoryProtocols.swift
// Service contracts for loading, probing, and hydrating machine inventory.
//
// App state and future settings screens depend on these protocols instead of
// concrete endpoint clients.

import Foundation

protocol MachineInventoryProviding: Sendable {
    func loadProbeRequests() async throws -> [MachineProbeRequest]
}

protocol EndpointProbing: Sendable {
    func probe(_ request: MachineProbeRequest) async -> MachineProbeResult
}

protocol RouteHydrating: Sendable {
    func hydrate(from results: [MachineProbeResult]) -> InventorySnapshot
    func diagnostics(from results: [MachineProbeResult]) -> [DiagnosticEvent]
}
