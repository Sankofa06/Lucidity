// ChatWorkspaceView.swift
// Primary chat-first workspace for Mira.
//
// Renders task selection, route selection, in-memory Free Chat streaming, and
// composer state. Root state supplies selected task, route, and chat model.

import SwiftUI

struct ChatWorkspaceView: View {
    @Bindable var appState: MiraAppState

    private var canSend: Bool {
        appState.chat.canSend(
            task: appState.selectedTask,
            route: appState.selectedRoute,
            inventory: appState.inventory
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatTopBar(appState: appState)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TaskPickerView(selectedTask: $appState.selectedTask)
                    RoutePickerView(appState: appState)
                    TranscriptPreviewView(appState: appState)
                }
                .padding(22)
            }
            ChatComposerView(appState: appState, canSend: canSend)
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
            MessageBubble(role: .system, text: "Mira is ready. Select a Free Chat LM Studio route to stream a response.")
            if let route = appState.selectedRoute {
                MessageBubble(
                    role: .diagnostic,
                    text: "\(route.friendlyName) is selected for \(appState.selectedTask.title)."
                )
            }
            ForEach(appState.chat.messages) { message in
                MessageBubble(
                    role: message.role,
                    text: message.text.isEmpty && message.role == .assistant ? "Responding..." : message.text,
                    isStreaming: appState.chat.isStreaming && message.id == appState.chat.messages.last?.id
                )
            }
        }
    }
}

private struct MessageBubble: View {
    let role: ChatMessage.Role
    let text: String
    var isStreaming = false

    var body: some View {
        MiraCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                        .shadow(color: isStreaming ? tint.opacity(0.9) : .clear, radius: MiraTheme.glowRadius)
                    Text(roleTitle.uppercased())
                }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MiraTheme.secondaryText)
                Text(text)
                    .font(.body)
                    .foregroundStyle(MiraTheme.text)
                    .textSelection(.enabled)
            }
        }
        .shadow(color: isStreaming ? MiraTheme.accent.opacity(0.25) : .clear, radius: MiraTheme.glowRadius)
    }

    private var roleTitle: String {
        switch role {
        case .user:
            "You"
        case .assistant:
            "Assistant"
        case .system:
            "System"
        case .diagnostic:
            "Route"
        }
    }

    private var tint: Color {
        switch role {
        case .user:
            MiraTheme.info
        case .assistant:
            MiraTheme.accent
        case .system:
            MiraTheme.success
        case .diagnostic:
            MiraTheme.warning
        }
    }
}

private struct ChatComposerView: View {
    @Bindable var appState: MiraAppState
    let canSend: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField(composerPlaceholder, text: $appState.chat.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(MiraTheme.text)
                    .disabled(appState.chat.isStreaming)
                AdvisorChip(title: "Prompt")
            }
            .padding(14)
            .background(MiraTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(canSend ? MiraTheme.accent.opacity(0.25) : MiraTheme.border, lineWidth: 1)
            }

            HStack {
                MiraChip(title: statusTitle, symbolName: statusSymbol, tint: statusTint)
                Spacer()
                if appState.chat.canStop {
                    Button("Stop") {
                        appState.chat.stop()
                    }
                    .buttonStyle(MiraSecondaryButtonStyle())
                } else {
                    Button("Send") {
                        appState.chat.send(appState: appState)
                    }
                    .buttonStyle(MiraPrimaryButtonStyle())
                    .disabled(!canSend)
                }
            }
        }
        .padding(18)
        .background(MiraTheme.rail)
    }

    private var composerPlaceholder: String {
        if appState.chat.isStreaming {
            return "LM Studio is responding..."
        }
        if canSend {
            return "Ask the selected LM Studio route..."
        }
        if case .chat(.free) = appState.selectedTask {
            return "Select an LM Studio route before sending"
        }
        return "Live sending is Free Chat only in this slice"
    }

    private var statusTitle: String {
        if appState.chat.isStreaming {
            return "Responding"
        }
        if canSend {
            return "Ready"
        }
        if case .chat(.free) = appState.selectedTask {
            return "Route required"
        }
        return "Free Chat only"
    }

    private var statusSymbol: String {
        if appState.chat.isStreaming {
            return "dot.radiowaves.left.and.right"
        }
        return canSend ? "checkmark.circle" : "scope"
    }

    private var statusTint: Color {
        if appState.chat.isStreaming {
            return MiraTheme.accent
        }
        return canSend ? MiraTheme.success : MiraTheme.warning
    }
}
