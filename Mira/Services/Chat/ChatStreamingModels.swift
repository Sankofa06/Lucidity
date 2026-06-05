// ChatStreamingModels.swift
// Shared streaming chat contracts and route resolution values.
//
// Chat view models depend on these protocols. LMStudioChatClient provides the
// first concrete OpenAI-compatible streaming implementation.

import Foundation

protocol ChatStreaming: Sendable {
    func streamResponse(
        messages: [ChatMessage],
        route: SmartRoute,
        endpoint: EngineEndpoint,
        machine: Machine
    ) -> AsyncThrowingStream<ChatStreamEvent, Error>
}

enum ChatStreamEvent: Equatable, Sendable {
    case delta(String)
    case finished
}

struct ChatRouteResolution: Hashable, Sendable {
    var route: SmartRoute
    var endpoint: EngineEndpoint
    var machine: Machine

    var address: EndpointAddress? {
        guard let port = endpoint.port else { return nil }
        return EndpointAddress(host: machine.hostDescription, port: port)
    }
}

enum ChatRouteResolver {
    static func resolve(route: SmartRoute?, inventory: InventorySnapshot) throws -> ChatRouteResolution {
        guard let route else {
            throw ChatRouteResolutionError.missingRoute
        }
        guard route.capabilities.contains(.text) else {
            throw ChatRouteResolutionError.unsupportedRoute("Selected route is not text-capable.")
        }
        guard let endpoint = inventory.endpoints.first(where: { $0.id == route.endpointID }) else {
            throw ChatRouteResolutionError.missingEndpoint
        }
        guard endpoint.engine == .lmStudio else {
            throw ChatRouteResolutionError.unsupportedRoute("Free Chat streaming supports LM Studio routes only in this slice.")
        }
        guard endpoint.port != nil else {
            throw ChatRouteResolutionError.missingEndpointPort
        }
        guard let machineID = route.machineID,
              let machine = inventory.machines.first(where: { $0.id == machineID }) else {
            throw ChatRouteResolutionError.missingMachine
        }

        return ChatRouteResolution(route: route, endpoint: endpoint, machine: machine)
    }
}

enum ChatRouteResolutionError: Error, Equatable {
    case missingRoute
    case missingEndpoint
    case missingEndpointPort
    case missingMachine
    case unsupportedRoute(String)

    var message: String {
        switch self {
        case .missingRoute:
            "Select an LM Studio route before sending."
        case .missingEndpoint:
            "The selected route no longer has a matching endpoint."
        case .missingEndpointPort:
            "The selected LM Studio endpoint is missing a port."
        case .missingMachine:
            "The selected route no longer has a matching machine."
        case .unsupportedRoute(let detail):
            detail
        }
    }
}
