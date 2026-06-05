// ChatWorkspaceViewModel.swift
// In-memory Free Chat state and streaming coordination.
//
// ChatWorkspaceView owns the transcript surface through MiraAppState. Streaming
// services perform network work while this view model coordinates UI state.

import Foundation
import Observation

@MainActor
@Observable
final class ChatWorkspaceViewModel {
    var inputText = ""
    var messages: [ChatMessage] = []
    var isStreaming = false
    var activeRunID: UUID?
    var activeRequestPath: String?
    var activeModelName: String?
    var activeEndpointSummary: String?
    var startedAt: Date?
    var completedAt: Date?
    var lastError: String?

    private var streamTask: Task<Void, Never>?

    var canStop: Bool {
        isStreaming && streamTask != nil
    }

    func canSend(task: ChatTask, route: SmartRoute?, inventory: InventorySnapshot) -> Bool {
        guard case .chat(.free) = task else { return false }
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !isStreaming else { return false }
        return (try? ChatRouteResolver.resolve(route: route, inventory: inventory)) != nil
    }

    @discardableResult
    func send(appState: MiraAppState, streamer: any ChatStreaming = LMStudioChatClient()) -> Task<Void, Never>? {
        guard canSend(task: appState.selectedTask, route: appState.selectedRoute, inventory: appState.inventory) else {
            reportFailure("Select a Free Chat LM Studio route and enter a prompt before sending.", appState: appState)
            return nil
        }

        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        let task = Task {
            await stream(prompt: prompt, appState: appState, streamer: streamer)
        }
        streamTask = task
        return task
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        completedAt = Date()
        if let activeRunID {
            lastError = "Stopped run \(activeRunID.uuidString.prefix(8))."
        }
        activeRunID = nil
    }

    private func stream(prompt: String, appState: MiraAppState, streamer: any ChatStreaming) async {
        do {
            let resolution = try ChatRouteResolver.resolve(route: appState.selectedRoute, inventory: appState.inventory)
            let userMessage = ChatMessage(id: UUID(), role: .user, text: prompt, routeID: resolution.route.id, createdAt: Date())
            messages.append(userMessage)

            let assistantID = UUID()
            let assistantMessage = ChatMessage(
                id: assistantID,
                role: .assistant,
                text: "",
                routeID: resolution.route.id,
                createdAt: Date()
            )
            messages.append(assistantMessage)

            isStreaming = true
            activeRunID = UUID()
            activeRequestPath = "/v1/chat/completions"
            activeModelName = resolution.route.modelName
            activeEndpointSummary = "\(resolution.endpoint.engine.title) :\(resolution.endpoint.port ?? 0)"
            startedAt = Date()
            completedAt = nil
            lastError = nil

            let requestMessages = messages.filter { $0.id != assistantID }
            for try await event in streamer.streamResponse(
                messages: requestMessages,
                route: resolution.route,
                endpoint: resolution.endpoint,
                machine: resolution.machine
            ) {
                try Task.checkCancellation()
                switch event {
                case .delta(let text):
                    append(text, toAssistantMessage: assistantID)
                case .finished:
                    finishStreaming()
                    return
                }
            }

            finishStreaming()
        } catch is CancellationError {
            stop()
        } catch let error as ChatRouteResolutionError {
            reportFailure(error.message, appState: appState)
        } catch {
            reportFailure("LM Studio stream failed: \(String(describing: error))", appState: appState)
        }
    }

    private func append(_ text: String, toAssistantMessage id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text.append(text)
    }

    private func finishStreaming() {
        isStreaming = false
        streamTask = nil
        completedAt = Date()
        activeRunID = nil
    }

    private func reportFailure(_ message: String, appState: MiraAppState) {
        lastError = message
        isStreaming = false
        streamTask = nil
        completedAt = Date()
        activeRunID = nil

        messages.append(
            ChatMessage(
                id: UUID(),
                role: .diagnostic,
                text: message,
                routeID: appState.selectedRoute?.id,
                createdAt: Date()
            )
        )
        appState.diagnostics.insert(
            DiagnosticEvent(
                id: UUID(),
                title: "Chat stream failed",
                detail: message,
                severity: .warning,
                progress: nil
            ),
            at: 0
        )
    }
}
