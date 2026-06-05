// LMStudioChatClient.swift
// OpenAI-compatible streaming chat client for LM Studio Free Chat.
//
// This client only posts chat-completion requests and reads SSE response
// deltas. It does not load, unload, mutate settings, or generate media.

import Foundation

struct LMStudioChatClient: ChatStreaming {
    var session: URLSession = .shared

    func streamResponse(
        messages: [ChatMessage],
        route: SmartRoute,
        endpoint: EngineEndpoint,
        machine: Machine
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let port = endpoint.port else {
                        throw ChatRouteResolutionError.missingEndpointPort
                    }
                    let request = try makeRequest(
                        messages: messages,
                        modelName: route.modelName,
                        address: EndpointAddress(host: machine.hostDescription, port: port)
                    )
                    let (bytes, response) = try await session.bytes(for: request)
                    try EndpointHTTPValidator.validate(response)

                    for try await line in bytes.lines {
                        for event in try LMStudioSSEParser.events(fromLine: line) {
                            continuation.yield(event)
                            if event == .finished {
                                continuation.finish()
                                return
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    func makeRequest(messages: [ChatMessage], modelName: String, address: EndpointAddress) throws -> URLRequest {
        let url = try EndpointURLBuilder.url(address: address, path: "/v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            LMStudioChatRequest(
                model: modelName,
                messages: messages.compactMap(LMStudioChatMessage.init(message:)),
                stream: true
            )
        )
        return request
    }
}

enum LMStudioSSEParser {
    static func events(fromLine line: String) throws -> [ChatStreamEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return [] }

        let payload = String(trimmed.dropFirst("data:".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { return [] }
        if payload == "[DONE]" {
            return [.finished]
        }

        let data = Data(payload.utf8)
        let chunk = try JSONDecoder().decode(LMStudioChatChunk.self, from: data)
        return chunk.choices.compactMap { choice in
            guard let content = choice.delta.content, !content.isEmpty else { return nil }
            return .delta(content)
        }
    }
}

private struct LMStudioChatRequest: Encodable {
    var model: String
    var messages: [LMStudioChatMessage]
    var stream: Bool
}

private struct LMStudioChatMessage: Encodable {
    var role: String
    var content: String

    init?(message: ChatMessage) {
        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch message.role {
        case .user:
            role = "user"
        case .assistant:
            role = "assistant"
        case .system:
            role = "system"
        case .diagnostic:
            return nil
        }
        content = trimmed
    }
}

private struct LMStudioChatChunk: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var delta: Delta
    }

    struct Delta: Decodable {
        var content: String?
    }
}
