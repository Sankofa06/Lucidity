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
            HubRow(title: "Smart Routes", subtitle: "\(appState.inventory.routes.count) public-safe fixture routes", symbolName: "point.3.connected.trianglepath.dotted")
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
    let appState: MiraAppState

    var body: some View {
        HubScaffold(eyebrow: "Machines", title: "Configured endpoints", subtitle: "Manual and Tailscale machine setup will hydrate route inventory without hardcoded private data.") {
            ForEach(appState.inventory.machines) { machine in
                HubRow(title: machine.name, subtitle: "\(machine.platform) · \(machine.hostDescription)", symbolName: "desktopcomputer")
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
