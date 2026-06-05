// MachineSettingsViewModelTests.swift
// Tests manual machine draft validation and inventory refresh coordination.
//
// The suite uses fake hosts and stub probe services only. It verifies the UI
// machine settings layer without touching real local endpoints or private data.

import Testing
@testable import Mira

struct MachineSettingsViewModelTests {
    @Test func draftValidationRejectsBlankName() {
        let draft = ConfiguredMachineDraft(displayName: " ", host: "example.tailnet.example", selectedPorts: [1234])

        #expect(draft.validationErrors.contains(.blankName))
    }

    @Test func draftValidationRejectsBlankHost() {
        let draft = ConfiguredMachineDraft(displayName: "Example", host: " ", selectedPorts: [1234])

        #expect(draft.validationErrors.contains(.blankHost))
    }

    @Test func draftValidationRequiresAtLeastOnePort() {
        let draft = ConfiguredMachineDraft(displayName: "Example", host: "example.tailnet.example", selectedPorts: [])

        #expect(draft.validationErrors.contains(.missingPorts))
    }

    @Test func draftNormalizesDuplicatePorts() throws {
        let draft = ConfiguredMachineDraft(displayName: "Example", host: "example.tailnet.example", selectedPorts: [7861, 1234, 7861])

        let request = try draft.probeRequest()

        #expect(request.expectedPorts == [1234, 7861])
    }

    @MainActor
    @Test func viewModelAddsEditsAndRemovesMachines() {
        let viewModel = MachineSettingsViewModel(machineDrafts: [])

        viewModel.addMachine()
        viewModel.machineDrafts[0].displayName = "Edited Machine"
        viewModel.machineDrafts[0].host = "edited.tailnet.example"
        viewModel.machineDrafts[0].setPort(8188, isEnabled: true)
        viewModel.removeMachine(id: viewModel.machineDrafts[0].id)

        #expect(viewModel.machineDrafts.isEmpty)
    }

    @MainActor
    @Test func refreshCallsPipelineAndAppliesInventoryToAppState() async {
        let draft = ConfiguredMachineDraft(
            displayName: "Example Chat Machine",
            host: "example-chat.tailnet.example",
            selectedPorts: [1234]
        )
        let viewModel = MachineSettingsViewModel(machineDrafts: [draft])
        let appState = MiraAppState(machineSettings: viewModel)

        await viewModel.refresh(appState: appState, prober: SuccessfulMachineProber())

        #expect(appState.inventory.machines.count == 1)
        #expect(appState.inventory.routes.count == 1)
        #expect(appState.selectedRoute?.modelName == "Example Live Model")
        #expect(appState.probeResults.count == 1)
    }

    @MainActor
    @Test func failedProbesBecomeDiagnosticsInsteadOfCrashes() async {
        let draft = ConfiguredMachineDraft(
            displayName: "Example Offline Machine",
            host: "offline.tailnet.example",
            selectedPorts: [1234]
        )
        let viewModel = MachineSettingsViewModel(machineDrafts: [draft])
        let appState = MiraAppState(machineSettings: viewModel)

        await viewModel.refresh(appState: appState, prober: FailingMachineProber())

        #expect(appState.inventory.routes.isEmpty)
        #expect(appState.diagnostics.contains { $0.title == "LM Studio probe failed" })
        #expect(appState.probeResults.first?.diagnostics.isEmpty == false)
    }
}

private struct SuccessfulMachineProber: EndpointProbing {
    func probe(_ request: MachineProbeRequest) async -> MachineProbeResult {
        MachineProbeResult(
            request: request,
            endpointSummaries: [
                EndpointProbeSummary(
                    address: EndpointAddress(host: request.host, port: 1234),
                    engine: .lmStudio,
                    health: .ready,
                    metadataSummary: "1 model",
                    modelSummaries: [
                        EndpointModelSummary(
                            id: "example-live-model",
                            displayName: "Example Live Model",
                            modelType: "llm",
                            contextLength: 4096,
                            state: "ready"
                        )
                    ]
                )
            ],
            diagnostics: []
        )
    }
}

private struct FailingMachineProber: EndpointProbing {
    func probe(_ request: MachineProbeRequest) async -> MachineProbeResult {
        MachineProbeResult(
            request: request,
            endpointSummaries: [],
            diagnostics: [
                ProbeDiagnostic(
                    title: "LM Studio probe failed",
                    detail: "The fake endpoint did not respond.",
                    severity: .warning
                )
            ]
        )
    }
}
