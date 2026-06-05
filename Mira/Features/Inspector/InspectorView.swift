// InspectorView.swift
// Contextual dashboard for Mira's selected route and app state.
//
// Chat owns the active work. Inspector provides route details, diagnostics,
// persona/team quick actions, and Developer Mode visibility.

import SwiftUI

struct InspectorView: View {
    @Bindable var appState: MiraAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MiraSectionHeader(
                    eyebrow: "Inspector",
                    title: "Studio status",
                    subtitle: "Route health, quick actions, diagnostics, and deeper context."
                )

                routeCard
                quickActions
                diagnosticsCard

                if appState.developerModeEnabled {
                    developerCard
                }
            }
            .padding(18)
        }
        .background(MiraTheme.rail)
        .overlay(alignment: .leading) {
            Rectangle().fill(MiraTheme.border).frame(width: 1)
        }
    }

    private var routeCard: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Selected Route")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MiraTheme.text)
                if let route = appState.selectedRoute {
                    Text(route.friendlyName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MiraTheme.text)
                    Text(route.modelName)
                        .foregroundStyle(MiraTheme.secondaryText)
                    HStack {
                        MiraChip(title: route.health.title, symbolName: "dot.radiowaves.left.and.right", tint: MiraTheme.success)
                        if route.isPinned {
                            MiraChip(title: "Pinned", symbolName: "pin", tint: MiraTheme.warning)
                        }
                    }
                } else {
                    Text("No route selected.")
                        .foregroundStyle(MiraTheme.secondaryText)
                }
            }
        }
    }

    private var quickActions: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Actions")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MiraTheme.text)
                HStack {
                    AdvisorChip(title: "Create Persona")
                    AdvisorChip(title: "Add To Team")
                }
                Text("Inspector-created personas and team membership will use the selected machine, endpoint, and model context.")
                    .font(.caption)
                    .foregroundStyle(MiraTheme.secondaryText)
            }
        }
    }

    private var diagnosticsCard: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Diagnostics")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MiraTheme.text)
                ForEach(appState.diagnostics) { event in
                    DiagnosticRow(event: event)
                }
            }
        }
    }

    private var developerCard: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Developer Mode")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MiraTheme.text)
                Text("Routes: \(appState.inventory.routes.count)")
                Text("Machines: \(appState.inventory.machines.count)")
                Text("Probe Results: \(appState.probeResults.count)")
                Text("Trusted Mode: \(appState.trustedModeEnabled ? "On" : "Off")")
                Divider().overlay(MiraTheme.border)
                Text("Chat Streaming: \(appState.chat.isStreaming ? "Running" : "Idle")")
                Text("Run ID: \(appState.chat.activeRunID?.uuidString ?? "None")")
                Text("Request: \(appState.chat.activeRequestPath ?? "None")")
                Text("Model: \(appState.chat.activeModelName ?? "None")")
                Text("Endpoint: \(appState.chat.activeEndpointSummary ?? "None")")
                if let startedAt = appState.chat.startedAt {
                    Text("Started: \(startedAt.formatted(date: .omitted, time: .standard))")
                }
                if let completedAt = appState.chat.completedAt {
                    Text("Completed: \(completedAt.formatted(date: .omitted, time: .standard))")
                }
                if let lastError = appState.chat.lastError {
                    Text("Last Error: \(lastError)")
                        .foregroundStyle(MiraTheme.warning)
                }
                Divider().overlay(MiraTheme.border)
                ForEach(appState.probeResults) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(result.request.machineName): \(result.endpointSummaries.count) endpoints")
                            .foregroundStyle(MiraTheme.text)
                        Text("\(result.request.host) ports \(result.request.expectedPorts.map(String.init).joined(separator: ","))")
                        ForEach(result.endpointSummaries) { summary in
                            Text("· \(summary.engine.title) :\(summary.address.port) \(summary.health.title)")
                        }
                        ForEach(result.diagnostics) { diagnostic in
                            Text("! \(diagnostic.title)")
                                .foregroundStyle(MiraTheme.warning)
                        }
                    }
                }
            }
            .font(.caption.monospaced())
            .foregroundStyle(MiraTheme.secondaryText)
        }
    }
}

private struct DiagnosticRow: View {
    let event: DiagnosticEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .shadow(color: color.opacity(0.7), radius: 8)
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MiraTheme.text)
            }
            Text(event.detail)
                .font(.caption)
                .foregroundStyle(MiraTheme.secondaryText)
            if let progress = event.progress {
                ProgressView(value: progress)
                    .tint(color)
            }
        }
    }

    private var color: Color {
        switch event.severity {
        case .info: MiraTheme.info
        case .success: MiraTheme.success
        case .warning: MiraTheme.warning
        }
    }
}
