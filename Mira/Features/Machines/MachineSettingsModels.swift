// MachineSettingsModels.swift
// Editable machine settings values for the Machines and Settings surfaces.
//
// The Machines feature owns these drafts. MachineSettingsViewModel converts
// them into inventory probe requests, and tests exercise validation here.

import Foundation

struct ConfiguredMachineDraft: Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var host: String
    var selectedPorts: [Int]

    init(
        id: UUID = UUID(),
        displayName: String = "New Machine",
        host: String = "",
        selectedPorts: [Int] = [MachinePortPreset.lmStudio.port]
    ) {
        self.id = id
        self.displayName = displayName
        self.host = host
        self.selectedPorts = selectedPorts
    }

    init(machine: Machine, endpoints: [EngineEndpoint]) {
        self.id = machine.id
        self.displayName = machine.name
        self.host = machine.hostDescription
        self.selectedPorts = endpoints.compactMap(\.port).normalizedPorts
    }

    var normalizedPorts: [Int] {
        selectedPorts.normalizedPorts
    }

    var validationErrors: [ConfiguredMachineValidationError] {
        var errors: [ConfiguredMachineValidationError] = []
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.blankName)
        }
        if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.blankHost)
        }
        if normalizedPorts.isEmpty {
            errors.append(.missingPorts)
        }
        return errors
    }

    var isValid: Bool {
        validationErrors.isEmpty
    }

    func probeRequest() throws -> MachineProbeRequest {
        let errors = validationErrors
        guard errors.isEmpty else {
            throw ConfiguredMachineDraftError.validationFailed(errors)
        }

        return MachineProbeRequest(
            id: id,
            machineName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
            expectedPorts: normalizedPorts
        )
    }

    mutating func setPort(_ port: Int, isEnabled: Bool) {
        if isEnabled {
            selectedPorts.append(port)
        } else {
            selectedPorts.removeAll { $0 == port }
        }
        selectedPorts = selectedPorts.normalizedPorts
    }
}

enum MachinePortPreset: Int, CaseIterable, Identifiable, Hashable {
    case lmStudio = 1234
    case a1111Primary = 7860
    case a1111Secondary = 7861
    case a1111Tertiary = 7862
    case a1111Quaternary = 7863
    case a1111Quinary = 7864
    case a1111Senary = 7865
    case comfyPrimary = 8188
    case comfySecondary = 8189

    var id: Int { rawValue }
    var port: Int { rawValue }

    var title: String {
        switch self {
        case .lmStudio:
            "LM Studio"
        case .a1111Primary:
            "A1111 / Forge"
        case .a1111Secondary:
            "Forge Alt"
        case .a1111Tertiary, .a1111Quaternary, .a1111Quinary, .a1111Senary:
            "A1111 Alt"
        case .comfyPrimary:
            "ComfyUI"
        case .comfySecondary:
            "ComfyUI Alt"
        }
    }

    var detail: String {
        switch self {
        case .lmStudio:
            "chat models"
        case .a1111Primary, .a1111Secondary, .a1111Tertiary, .a1111Quaternary, .a1111Quinary, .a1111Senary:
            "image engines"
        case .comfyPrimary, .comfySecondary:
            "workflows"
        }
    }
}

enum InventoryRefreshState: Equatable, Hashable {
    case idle
    case refreshing
    case refreshed(Date)
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            "Ready to refresh"
        case .refreshing:
            "Refreshing"
        case .refreshed:
            "Inventory refreshed"
        case .failed:
            "Refresh needs attention"
        }
    }
}

enum ConfiguredMachineValidationError: String, Equatable, Hashable {
    case blankName
    case blankHost
    case missingPorts

    var message: String {
        switch self {
        case .blankName:
            "Add a display name."
        case .blankHost:
            "Add a host, IP address, or DNS name."
        case .missingPorts:
            "Select at least one expected endpoint port."
        }
    }
}

enum ConfiguredMachineDraftError: Error, Equatable {
    case validationFailed([ConfiguredMachineValidationError])
}

private extension Array where Element == Int {
    var normalizedPorts: [Int] {
        Array(Set(self)).sorted()
    }
}
