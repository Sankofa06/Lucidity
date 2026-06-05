// ChatWorkspaceView.swift
// Primary chat-first workspace for Mira.
//
// Renders task selection, route selection, transcript scaffolding, and composer
// state. Root state supplies selected task and route.

import SwiftUI

struct ChatWorkspaceView: View {
    @Bindable var appState: MiraAppState

    private var canSend: Bool {
        RouteValidator.canSend(task: appState.selectedTask, route: appState.selectedRoute)
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatTopBar(appState: appState)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MiraSectionHeader(
                        eyebrow: "Mira Chat",
                        title: "Choose a task, then route it.",
                        subtitle: "Free chat, group chat, compare, media planning, endpoint inspection, and workflows all start here."
                    )

                    TaskPickerView(selectedTask: $appState.selectedTask)
                    RoutePickerView(appState: appState)
                    TranscriptPreviewView(appState: appState)
                }
                .padding(22)
            }
            ChatComposerView(canSend: canSend)
        }
        .background(MiraTheme.background)
    }
}

private struct ChatTopBar: View {
    @Bindable var appState: MiraAppState

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.selectedProject.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MiraTheme.text)
                Text(appState.selectedRoute?.friendlyName ?? "No route selected")
                    .font(.caption)
                    .foregroundStyle(MiraTheme.secondaryText)
            }

            Spacer()

            AdvisorChip(title: "Help")
            MiraChip(title: appState.developerModeEnabled ? "Developer" : "Normal", symbolName: "slider.horizontal.3")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(MiraTheme.rail)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MiraTheme.border).frame(height: 1)
        }
    }
}

private struct TranscriptPreviewView: View {
    let appState: MiraAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MessageBubble(role: "System", text: "Mira is ready. Select a task and route to begin.")
            if let route = appState.selectedRoute {
                MessageBubble(
                    role: "Route",
                    text: "\(route.friendlyName) is selected for \(appState.selectedTask.title)."
                )
            }
        }
    }
}

private struct MessageBubble: View {
    let role: String
    let text: String

    var body: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(role.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MiraTheme.secondaryText)
                Text(text)
                    .font(.body)
                    .foregroundStyle(MiraTheme.text)
            }
        }
    }
}

private struct ChatComposerView: View {
    let canSend: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(canSend ? "Ask Mira or describe what to create..." : "Select a route before sending")
                    .font(.subheadline)
                    .foregroundStyle(canSend ? MiraTheme.text : MiraTheme.secondaryText)
                Spacer()
                AdvisorChip(title: "Prompt")
            }
            .padding(14)
            .background(MiraTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(canSend ? MiraTheme.accent.opacity(0.25) : MiraTheme.border, lineWidth: 1)
            }

            HStack {
                MiraChip(title: canSend ? "Ready" : "Route required", symbolName: canSend ? "checkmark.circle" : "scope", tint: canSend ? MiraTheme.success : MiraTheme.warning)
                Spacer()
                Button("Send") { }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSend)
            }
        }
        .padding(18)
        .background(MiraTheme.rail)
    }
}
