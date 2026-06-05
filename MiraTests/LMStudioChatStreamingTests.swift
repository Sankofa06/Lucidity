// LMStudioChatStreamingTests.swift
// Tests LM Studio Free Chat streaming request, parser, resolver, and view model.
//
// The suite uses fake hosts and mocked streams only. No committed test touches
// private local endpoints or live LM Studio servers.

import Foundation
import Testing
@testable import Mira

struct LMStudioChatStreamingTests {
    @Test func sseParserEmitsDeltasAndFinishesOnDone() throws {
        let delta = try LMStudioSSEParser.events(
            fromLine: #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#
        )
        let done = try LMStudioSSEParser.events(fromLine: "data: [DONE]")

        #expect(delta == [.delta("Hello")])
        #expect(done == [.finished])
    }

    @Test func sseParserIgnoresEmptyAndNonDataLines() throws {
        #expect(try LMStudioSSEParser.events(fromLine: "").isEmpty)
        #expect(try LMStudioSSEParser.events(fromLine: "event: message").isEmpty)
        #expect(try LMStudioSSEParser.events(fromLine: "data: ").isEmpty)
    }

    @Test func sseParserReportsMalformedJSON() {
        #expect(throws: Error.self) {
            _ = try LMStudioSSEParser.events(fromLine: "data: {not-json}")
        }
    }

    @Test func lmStudioClientBuildsStreamingChatRequest() throws {
        let client = LMStudioChatClient(session: .shared)
        let request = try client.makeRequest(
            messages: [
                ChatMessage(id: UUID(), role: .system, text: "You are concise.", routeID: nil, createdAt: Date()),
                ChatMessage(id: UUID(), role: .user, text: "Hello", routeID: nil, createdAt: Date()),
                ChatMessage(id: UUID(), role: .diagnostic, text: "Ignore diagnostics", routeID: nil, createdAt: Date())
            ],
            modelName: "example-model",
            address: EndpointAddress(host: "example.test", port: 1234)
        )

        #expect(request.url?.absoluteString == "http://example.test:1234/v1/chat/completions")
        #expect(request.httpMethod == "POST")

        let body = try #require(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["model"] as? String == "example-model")
        #expect(json?["stream"] as? Bool == true)
        let messages = try #require(json?["messages"] as? [[String: Any]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] as? String == "system")
        #expect(messages[1]["role"] as? String == "user")
    }

    @Test func routeResolverAcceptsSelectedLMStudioTextRoute() throws {
        let route = try #require(MockMiraData.inventory.routes.first { $0.capabilities.contains(.text) })

        let resolution = try ChatRouteResolver.resolve(route: route, inventory: MockMiraData.inventory)

        #expect(resolution.endpoint.engine == .lmStudio)
        #expect(resolution.address?.port == 1234)
    }

    @Test func routeResolverRejectsNonLMStudioRoutes() throws {
        let route = try #require(MockMiraData.inventory.routes.first { $0.capabilities.contains(.workflow) })

        #expect(throws: ChatRouteResolutionError.self) {
            _ = try ChatRouteResolver.resolve(route: route, inventory: MockMiraData.inventory)
        }
    }

    @MainActor
    @Test func chatViewModelStreamsDeltasIntoAssistantMessage() async {
        let chat = ChatWorkspaceViewModel()
        chat.inputText = "Say hello"
        let appState = MiraAppState(chat: chat)
        appState.selectedRoute = MockMiraData.inventory.routes.first { $0.capabilities.contains(.text) }

        let task = chat.send(appState: appState, streamer: MockChatStreamer(events: [.delta("Hel"), .delta("lo"), .finished]))
        await task?.value

        #expect(chat.messages.contains { $0.role == .user && $0.text == "Say hello" })
        #expect(chat.messages.contains { $0.role == .assistant && $0.text == "Hello" })
        #expect(chat.isStreaming == false)
    }

    @MainActor
    @Test func failedStreamBecomesDiagnosticWithoutLosingTranscript() async {
        let chat = ChatWorkspaceViewModel()
        chat.inputText = "Try once"
        let appState = MiraAppState(chat: chat)
        appState.selectedRoute = MockMiraData.inventory.routes.first { $0.capabilities.contains(.text) }

        let task = chat.send(appState: appState, streamer: MockChatStreamer(error: ChatTestError.streamFailed))
        await task?.value

        #expect(chat.messages.contains { $0.role == .user && $0.text == "Try once" })
        #expect(chat.messages.contains { $0.role == .diagnostic })
        #expect(appState.diagnostics.first?.title == "Chat stream failed")
    }

    @MainActor
    @Test func composerSendRulesRequireFreeChatLMStudioRouteAndPrompt() {
        let chat = ChatWorkspaceViewModel()
        let appState = MiraAppState(chat: chat)
        appState.selectedRoute = MockMiraData.inventory.routes.first { $0.capabilities.contains(.text) }

        #expect(chat.canSend(task: .chat(.free), route: appState.selectedRoute, inventory: appState.inventory) == false)

        chat.inputText = "Hello"
        #expect(chat.canSend(task: .chat(.free), route: appState.selectedRoute, inventory: appState.inventory))
        #expect(chat.canSend(task: .chat(.compare), route: appState.selectedRoute, inventory: appState.inventory) == false)
    }
}

private enum ChatTestError: Error {
    case streamFailed
}

private struct MockChatStreamer: ChatStreaming {
    var events: [ChatStreamEvent] = []
    var error: Error?

    func streamResponse(
        messages: [ChatMessage],
        route: SmartRoute,
        endpoint: EngineEndpoint,
        machine: Machine
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            if let error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }
}
