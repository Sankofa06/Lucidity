// SettingsHubView.swift
// Organized first-class settings shell for Mira.
//
// Settings owns Developer Mode and Trusted Mode toggles and previews the
// sections that will later wire Keychain, sync, providers, and release metadata.

import SwiftUI

struct SettingsHubView: View {
    @Bindable var appState: MiraAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MiraSectionHeader(
                    eyebrow: "Settings",
                    title: "Control center",
                    subtitle: "Organized app, provider, source, Advisor, developer, diagnostic, privacy, and release settings."
                )

                machinesEndpointEntry
                developerSettings
                settingsGrid
            }
            .padding(22)
        }
        .background(MiraTheme.background)
    }

    private var machinesEndpointEntry: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "network")
                        .foregroundStyle(MiraTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(MiraTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Machines & Endpoints")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(MiraTheme.text)
                        Text("\(appState.machineSettings.machineDrafts.count) configured drafts · \(appState.inventory.routes.count) hydrated routes")
                            .font(.caption)
                            .foregroundStyle(MiraTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        appState.selectedSection = .machines
                    } label: {
                        Label("Open", systemImage: "arrow.right")
                    }
                    .buttonStyle(MiraSecondaryButtonStyle())
                }

                Text("Real hosts, Tailscale IPs, API keys, and endpoint snapshots must stay out of source control. Optional local smoke-test config belongs in ignored LocalDev/machines.local.json.")
                    .font(.caption)
                    .foregroundStyle(MiraTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var developerSettings: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Developer Settings")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MiraTheme.text)
                Toggle("Developer Mode", isOn: $appState.developerModeEnabled)
                    .tint(MiraTheme.accent)
                Toggle("Trusted Mode", isOn: $appState.trustedModeEnabled)
                    .tint(MiraTheme.warning)
                Text("Trusted Mode stays here and defaults off. Later it can auto-run only validated Advisor plans.")
                    .font(.caption)
                    .foregroundStyle(MiraTheme.secondaryText)
            }
        }
    }

    private var settingsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    if section == .machines {
                        appState.selectedSection = .machines
                    }
                } label: {
                    MiraCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: section.symbolName)
                                .foregroundStyle(MiraTheme.accent)
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MiraTheme.text)
                            Text(section.summary)
                                .font(.caption)
                                .foregroundStyle(MiraTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case machines
    case cloud
    case sources
    case advisor
    case personas
    case projects
    case diagnostics
    case privacy
    case release

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance & Themes"
        case .machines: "Machines & Endpoints"
        case .cloud: "Cloud Providers & API Keys"
        case .sources: "Model Sources"
        case .advisor: "Advisor"
        case .personas: "Personas & Teams"
        case .projects: "Projects & Sessions"
        case .diagnostics: "Diagnostics & Logs"
        case .privacy: "Privacy & Sync"
        case .release: "App Store / Release Info"
        }
    }

    var summary: String {
        switch self {
        case .general: "App behavior, defaults, and workspace preferences."
        case .appearance: "Theme tokens for color, type, spacing, sizing, and glow."
        case .machines: "Manual machines, Tailscale import, probes, and routes."
        case .cloud: "Keychain-backed provider credentials when functional."
        case .sources: "Hugging Face and CivitAI keys, metadata, and downloads."
        case .advisor: "Default Advisor route and confirmation behavior."
        case .personas: "Persona defaults, roles, characters, memory, and web search."
        case .projects: "Persistent sessions and lightweight project containers."
        case .diagnostics: "Logs, timing, validation, and background events."
        case .privacy: "Local-first data, sync placeholders, and export controls."
        case .release: "Version, build, metadata, and release readiness."
        }
    }

    var symbolName: String {
        switch self {
        case .general: "switch.2"
        case .appearance: "paintpalette"
        case .machines: "network"
        case .cloud: "key"
        case .sources: "square.and.arrow.down"
        case .advisor: "sparkle.magnifyingglass"
        case .personas: "person.crop.circle"
        case .projects: "folder"
        case .diagnostics: "waveform.path.ecg"
        case .privacy: "lock.shield"
        case .release: "shippingbox"
        }
    }
}
