// MiraAppState.swift
// Shared root state for Mira's first-build app shell.
//
// Holds navigation, developer settings, and mock inventory used by the initial
// UI. Root views mutate this object; domain and service layers provide the
// values it exposes.

import Foundation
import Observation

@MainActor
@Observable
final class MiraAppState {
    var selectedSection: MiraSection = .chat
    var selectedTask: ChatTask = .chat(.free)
    var selectedRoute: SmartRoute?
    var selectedProject: MiraProject
    var selectedPersona: Persona?
    var selectedTeam: Team?
    var developerModeEnabled = false
    var trustedModeEnabled = false
    var advisorConfiguration: AdvisorConfiguration
    var inventory: InventorySnapshot
    var diagnostics: [DiagnosticEvent]
    var probeResults: [MachineProbeResult] = []

    init(
        selectedProject: MiraProject = MockMiraData.projects[0],
        advisorConfiguration: AdvisorConfiguration = MockMiraData.advisor,
        inventory: InventorySnapshot = MockMiraData.inventory,
        diagnostics: [DiagnosticEvent] = MockMiraData.diagnostics
    ) {
        self.selectedProject = selectedProject
        self.advisorConfiguration = advisorConfiguration
        self.inventory = inventory
        self.diagnostics = diagnostics
        self.selectedRoute = nil
        self.selectedPersona = MockMiraData.personas.first
        self.selectedTeam = MockMiraData.teams.first
    }

    func applyInventoryRefresh(_ refresh: MachineInventoryRefresh) {
        inventory = refresh.inventory
        diagnostics = refresh.diagnostics
        probeResults = refresh.probeResults
        selectedRoute = refresh.inventory.routes.first
    }
}
