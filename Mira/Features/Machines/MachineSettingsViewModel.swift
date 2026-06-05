// MachineSettingsViewModel.swift
// Coordinates in-memory machine drafts and read-only inventory refreshes.
//
// MachinesHubView and SettingsHubView mutate this model. It converts user-safe
// draft values into MachineInventoryService inputs and applies refreshed app
// inventory through MiraAppState.

import Foundation
import Observation

@MainActor
@Observable
final class MachineSettingsViewModel {
    var machineDrafts: [ConfiguredMachineDraft]
    var selectedDraftID: UUID?
    var refreshState: InventoryRefreshState = .idle
    var lastProbeResults: [MachineProbeResult] = []

    init(machineDrafts: [ConfiguredMachineDraft] = MachineSettingsViewModel.mockDrafts()) {
        self.machineDrafts = machineDrafts
        self.selectedDraftID = machineDrafts.first?.id
    }

    func addMachine() {
        let draft = ConfiguredMachineDraft()
        machineDrafts.append(draft)
        selectedDraftID = draft.id
    }

    func removeMachine(id: UUID) {
        machineDrafts.removeAll { $0.id == id }
        if selectedDraftID == id {
            selectedDraftID = machineDrafts.first?.id
        }
    }

    func duplicateMachine(id: UUID) {
        guard let draft = machineDrafts.first(where: { $0.id == id }) else { return }
        let copy = ConfiguredMachineDraft(
            displayName: "\(draft.displayName) Copy",
            host: draft.host,
            selectedPorts: draft.normalizedPorts
        )
        machineDrafts.append(copy)
        selectedDraftID = copy.id
    }

    func probeRequests() throws -> [MachineProbeRequest] {
        try machineDrafts.map { try $0.probeRequest() }
    }

    func refresh(
        appState: MiraAppState,
        prober: (any EndpointProbing)? = nil,
        hydrator: any RouteHydrating = RouteHydrationService()
    ) async {
        refreshState = .refreshing

        do {
            let requests = try probeRequests()
            let service = MachineInventoryService(
                provider: DraftMachineInventoryProvider(requests: requests),
                prober: prober ?? defaultProber(for: requests),
                hydrator: hydrator
            )
            let refresh = try await service.refreshInventory()
            appState.applyInventoryRefresh(refresh)
            lastProbeResults = refresh.probeResults
            refreshState = .refreshed(Date())
        } catch let error as ConfiguredMachineDraftError {
            refreshState = .failed(error.failureMessage)
        } catch {
            refreshState = .failed(String(describing: error))
        }
    }

    private func defaultProber(for requests: [MachineProbeRequest]) -> any EndpointProbing {
        if requests.allSatisfy({ $0.host.localizedCaseInsensitiveContains(".example") }) {
            return MockEndpointProbeService()
        }

        return EndpointProbeService(
            lmStudioClient: LMStudioHTTPClient(),
            automatic1111Client: Automatic1111HTTPClient(),
            comfyUIClient: ComfyUIHTTPClient()
        )
    }

    private static func mockDrafts() -> [ConfiguredMachineDraft] {
        MockMiraData.inventory.machines.map { machine in
            let endpoints = MockMiraData.inventory.endpoints.filter { $0.machineID == machine.id }
            return ConfiguredMachineDraft(machine: machine, endpoints: endpoints)
        }
    }
}

struct DraftMachineInventoryProvider: MachineInventoryProviding {
    var requests: [MachineProbeRequest]

    func loadProbeRequests() async throws -> [MachineProbeRequest] {
        requests
    }
}

private extension ConfiguredMachineDraftError {
    var failureMessage: String {
        switch self {
        case .validationFailed(let errors):
            errors.map(\.message).joined(separator: " ")
        }
    }
}
