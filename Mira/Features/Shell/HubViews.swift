// HubViews.swift
// First-class Mira section shells beyond Chat.
//
// These hubs keep navigation shallow while later feature work fills in editing,
// persistence, and endpoint actions.

import SwiftUI

struct ProjectHubView: View {
    let appState: MiraAppState

    var body: some View {
        HubScaffold(eyebrow: "Projects", title: "Lightweight containers", subtitle: "Group sessions, personas, teams, routes, workflows, and source context.") {
            ForEach(MockMiraData.projects) { project in
                HubRow(title: project.name, subtitle: "\(project.sessionCount) sessions · \(project.summary)", symbolName: "folder")
            }
        }
    }
}

struct PersonaHubView: View {
    let appState: MiraAppState

    var body: some View {
        HubScaffold(eyebrow: "Personas", title: "Chat and media identities", subtitle: "Create named roles with route defaults, memory, web search, and expandable media settings.") {
            ForEach(MockMiraData.personas) { persona in
                HubRow(
                    title: persona.name,
                    subtitle: "\(persona.role) · media \(persona.mediaEnabled ? "enabled" : "off")",
                    symbolName: "person.crop.circle"
                )
            }
            AdvisorChip(title: "Create Persona")
        }
    }
}

struct TeamHubView: View {
    let appState: MiraAppState

    var body: some View {
        HubScaffold(eyebrow: "Teams", title: "Ordered model groups", subtitle: "Teams use the same orchestration engine as group chat and compare.") {
            ForEach(MockMiraData.teams) { team in
                HubRow(title: team.name, subtitle: team.purpose, symbolName: "person.3")
            }
        }
    }
}

struct LibraryHubView: View {
    let appState: MiraAppState

    var body: some View {
        HubScaffold(eyebrow: "Library", title: "Local inventory", subtitle: "Machines, endpoints, routes, models, checkpoints, LoRAs, workflows, and linked assets.") {
            HubRow(title: "Smart Routes", subtitle: "\(appState.inventory.routes.count) hydrated routes", symbolName: "point.3.connected.trianglepath.dotted")
            HubRow(title: "Workflows", subtitle: "\(MockMiraData.workflows.count) workflow shell", symbolName: "point.topleft.down.curvedto.point.bottomright.up")
        }
    }
}

struct ModelSourcesHubView: View {
    let appState: MiraAppState

    var body: some View {
        HubScaffold(eyebrow: "Model Sources", title: "Hugging Face and CivitAI", subtitle: "Search, metadata, download planning, trigger words, licenses, and installed-file matching.") {
            ForEach(MockMiraData.sources) { source in
                HubRow(
                    title: source.kind.title,
                    subtitle: source.isKeyConfigured ? "Key configured" : source.summary,
                    symbolName: "square.and.arrow.down"
                )
            }
        }
    }
}

struct MachinesHubView: View {
    @Bindable var appState: MiraAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MiraSectionHeader(
                    eyebrow: "Machines",
                    title: "Configured endpoints",
                    subtitle: "Add machines, choose expected read-only ports, refresh inventory, and hydrate routes without hardcoded private data."
                )

                MachinePrivacyNotice()
                machineToolbar
                machineEditors
                refreshSummary
                probeResults
            }
            .padding(22)
        }
        .background(MiraTheme.background)
    }

    private var machineToolbar: some View {
        HStack(spacing: 10) {
            Button {
                appState.machineSettings.addMachine()
            } label: {
                Label("Add Machine", systemImage: "plus")
            }
            .buttonStyle(MiraPrimaryButtonStyle())

            Button {
                Task {
                    await appState.machineSettings.refresh(appState: appState)
                }
            } label: {
                Label("Refresh Inventory", systemImage: "arrow.clockwise")
            }
            .buttonStyle(MiraSecondaryButtonStyle())
            .disabled(appState.machineSettings.refreshState == .refreshing)

            Spacer()

            MiraChip(
                title: "\(appState.inventory.routes.count) routes",
                symbolName: "point.3.connected.trianglepath.dotted",
                tint: MiraTheme.success
            )
        }
    }

    private var machineEditors: some View {
        VStack(spacing: 12) {
            ForEach(appState.machineSettings.machineDrafts.indices, id: \.self) { index in
                MachineDraftCard(
                    draft: $appState.machineSettings.machineDrafts[index],
                    onDuplicate: {
                        appState.machineSettings.duplicateMachine(id: appState.machineSettings.machineDrafts[index].id)
                    },
                    onRemove: {
                        appState.machineSettings.removeMachine(id: appState.machineSettings.machineDrafts[index].id)
                    }
                )
            }
        }
    }

    private var refreshSummary: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(appState.machineSettings.refreshState.title, systemImage: refreshSymbolName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MiraTheme.text)
                    Spacer()
                    if case .refreshing = appState.machineSettings.refreshState {
                        ProgressView()
                            .tint(MiraTheme.accent)
                    }
                }

                Text(refreshDetail)
                    .font(.caption)
                    .foregroundStyle(MiraTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    MiraChip(title: "\(appState.inventory.machines.count) machines", symbolName: "desktopcomputer", tint: MiraTheme.info)
                    MiraChip(title: "\(appState.inventory.endpoints.count) endpoints", symbolName: "network", tint: MiraTheme.info)
                    MiraChip(title: "\(appState.probeResults.count) probe results", symbolName: "waveform.path.ecg", tint: MiraTheme.warning)
                }
            }
        }
    }

    private var probeResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Probe Results")
                .font(.headline.weight(.semibold))
                .foregroundStyle(MiraTheme.text)

            if appState.probeResults.isEmpty {
                HubRow(
                    title: "No refresh run yet",
                    subtitle: "Use Refresh Inventory after confirming machine hosts and expected ports.",
                    symbolName: "waveform.path.ecg"
                )
            } else {
                ForEach(appState.probeResults) { result in
                    MachineProbeResultRow(result: result)
                }
            }
        }
    }

    private var refreshSymbolName: String {
        switch appState.machineSettings.refreshState {
        case .idle:
            "clock"
        case .refreshing:
            "arrow.clockwise"
        case .refreshed:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        }
    }

    private var refreshDetail: String {
        switch appState.machineSettings.refreshState {
        case .idle:
            "Refresh uses only the machines listed here. Mira does not use private hosts unless you type them or load ignored local config."
        case .refreshing:
            "Read-only probes are checking LM Studio, A1111/Forge, and ComfyUI metadata endpoints."
        case .refreshed(let date):
            "Last refreshed \(date.formatted(date: .abbreviated, time: .shortened)). Chat, Inspector, Machines, and Library now read the hydrated inventory."
        case .failed(let message):
            message
        }
    }
}

private struct MachinePrivacyNotice: View {
    var body: some View {
        MiraCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(MiraTheme.warning)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Private endpoint data stays local")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MiraTheme.text)
                    Text("Do not commit real hosts, Tailscale IPs, API keys, or endpoint snapshots. For smoke testing, use ignored LocalDev/machines.local.json or values typed in this screen.")
                        .font(.caption)
                        .foregroundStyle(MiraTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct MachineDraftCard: View {
    @Binding var draft: ConfiguredMachineDraft
    let onDuplicate: () -> Void
    let onRemove: () -> Void

    var body: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Machine", systemImage: "desktopcomputer")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MiraTheme.text)
                    Spacer()
                    Button(action: onDuplicate) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(MiraIconButtonStyle())
                    .accessibilityLabel("Duplicate machine")
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(MiraIconButtonStyle(tint: MiraTheme.warning))
                    .accessibilityLabel("Remove machine")
                }

                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Display Name") {
                        TextField("Studio Mac", text: $draft.displayName)
                            .textFieldStyle(MiraTextFieldStyle())
                    }
                    LabeledContent("Host / IP / DNS") {
                        TextField("host.tailnet.example", text: $draft.host)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(MiraTextFieldStyle())
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(MiraTheme.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Expected Ports")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MiraTheme.secondaryText)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                        ForEach(MachinePortPreset.allCases) { preset in
                            MachinePortChip(
                                preset: preset,
                                isSelected: draft.normalizedPorts.contains(preset.port)
                            ) {
                                draft.setPort(preset.port, isEnabled: !draft.normalizedPorts.contains(preset.port))
                            }
                        }
                    }
                }

                if !draft.validationErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(draft.validationErrors, id: \.self) { error in
                            Label(error.message, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(MiraTheme.warning)
                        }
                    }
                }
            }
        }
    }
}

private struct MachinePortChip: View {
    let preset: MachinePortPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(preset.port)")
                        .font(.caption.weight(.bold))
                    Text(preset.title)
                        .font(.caption2)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? MiraTheme.text : MiraTheme.secondaryText)
            .padding(9)
            .frame(minHeight: 46)
            .background(isSelected ? MiraTheme.accent.opacity(0.16) : MiraTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? MiraTheme.accent.opacity(0.45) : MiraTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MachineProbeResultRow: View {
    let result: MachineProbeResult

    var body: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.request.machineName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MiraTheme.text)
                        Text("\(result.request.host) · ports \(result.request.expectedPorts.map(String.init).joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(MiraTheme.secondaryText)
                    }
                    Spacer()
                    MiraChip(title: "\(result.endpointSummaries.count) found", symbolName: "checkmark.seal", tint: result.endpointSummaries.isEmpty ? MiraTheme.warning : MiraTheme.success)
                }

                ForEach(result.endpointSummaries) { summary in
                    HubRow(
                        title: "\(summary.engine.title) :\(summary.address.port)",
                        subtitle: "\(summary.health.title) · \(summary.metadataSummary)",
                        symbolName: "network"
                    )
                }

                ForEach(result.diagnostics) { diagnostic in
                    Label(diagnostic.title, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(MiraTheme.warning)
                }
            }
        }
    }
}

struct HubScaffold<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let content: Content

    init(eyebrow: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MiraSectionHeader(eyebrow: eyebrow, title: title, subtitle: subtitle)
                MiraCard {
                    VStack(spacing: 10) {
                        content
                    }
                }
            }
            .padding(22)
        }
        .background(MiraTheme.background)
    }
}

struct HubRow: View {
    let title: String
    let subtitle: String
    let symbolName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(MiraTheme.accent)
                .frame(width: 34, height: 34)
                .background(MiraTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MiraTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MiraTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(10)
        .background(MiraTheme.elevated, in: RoundedRectangle(cornerRadius: 8))
    }
}
