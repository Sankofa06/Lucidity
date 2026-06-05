// EndpointHTTPClients.swift
// Concrete read-only HTTP clients for Mira's local engine endpoints.
//
// These clients perform URLSession reads only. Generation, load/unload, and
// settings mutation belong in explicit later services with separate tests.

import Foundation

struct LMStudioHTTPClient: LMStudioReadableClient {
    var session: URLSession = .shared

    func listModels(at address: EndpointAddress) async throws -> [EndpointModelSummary] {
        let url = try EndpointURLBuilder.url(address: address, path: "/api/v0/models")
        let envelope = try await decode(LMStudioModelsEnvelope.self, from: url)
        return envelope.data.map {
            EndpointModelSummary(
                id: $0.id,
                displayName: $0.id,
                modelType: $0.type ?? "model",
                contextLength: $0.maxContextLength,
                state: $0.state
            )
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        try EndpointHTTPValidator.validate(response)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

struct Automatic1111HTTPClient: Automatic1111ReadableClient {
    var session: URLSession = .shared

    func readInventory(at address: EndpointAddress) async throws -> ImageEndpointInventory {
        async let checkpoints = decode([A1111NamedItem].self, address: address, path: "/sdapi/v1/sd-models")
        async let loras = decode([A1111NamedItem].self, address: address, path: "/sdapi/v1/loras")
        async let vaes = decodeIfAvailable([A1111NamedItem].self, address: address, path: "/sdapi/v1/sd-vae")
        async let samplers = decode([A1111NamedItem].self, address: address, path: "/sdapi/v1/samplers")
        async let schedulers = decodeIfAvailable([A1111NamedItem].self, address: address, path: "/sdapi/v1/schedulers")
        async let extensions = decode([A1111ExtensionItem].self, address: address, path: "/sdapi/v1/extensions")

        return try await ImageEndpointInventory(
            checkpoints: checkpoints.map(\.resolvedName),
            loras: loras.map(\.resolvedName),
            vaes: vaes.map(\.resolvedName),
            samplers: samplers.map(\.resolvedName),
            schedulers: schedulers.map(\.resolvedName),
            extensions: extensions.map(\.name)
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, address: EndpointAddress, path: String) async throws -> T {
        let url = try EndpointURLBuilder.url(address: address, path: path)
        let (data, response) = try await session.data(from: url)
        try EndpointHTTPValidator.validate(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func decodeIfAvailable<T: Decodable>(_ type: T.Type, address: EndpointAddress, path: String) async throws -> T {
        do {
            return try await decode(type, address: address, path: path)
        } catch EndpointHTTPError.notFound {
            let emptyArray = Data("[]".utf8)
            return try JSONDecoder().decode(T.self, from: emptyArray)
        }
    }
}

struct ComfyUIHTTPClient: ComfyUIReadableClient {
    var session: URLSession = .shared

    func readSystem(at address: EndpointAddress) async throws -> ComfyUISystemSummary {
        async let stats = decode(ComfySystemStats.self, address: address, path: "/system_stats")
        async let objectInfo = decode([String: ComfyNodeInfo].self, address: address, path: "/object_info")
        async let queue = decode(ComfyQueue.self, address: address, path: "/queue")

        let resolvedStats = try await stats
        let resolvedQueue = try await queue
        let nodes = try await objectInfo

        return ComfyUISystemSummary(
            version: resolvedStats.system.comfyuiVersion,
            operatingSystem: resolvedStats.system.os,
            devices: resolvedStats.devices.map(\.name),
            nodeCount: nodes.count,
            queueRunning: resolvedQueue.queueRunning.count,
            queuePending: resolvedQueue.queuePending.count
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, address: EndpointAddress, path: String) async throws -> T {
        let url = try EndpointURLBuilder.url(address: address, path: path)
        let (data, response) = try await session.data(from: url)
        try EndpointHTTPValidator.validate(response)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum EndpointHTTPValidator {
    static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300:
            return
        case 404:
            throw EndpointHTTPError.notFound
        default:
            throw EndpointHTTPError.status(http.statusCode)
        }
    }
}

enum EndpointHTTPError: Error, Equatable {
    case notFound
    case status(Int)
}

private struct LMStudioModelsEnvelope: Decodable {
    var data: [LMStudioModel]
}

private struct LMStudioModel: Decodable {
    var id: String
    var type: String?
    var state: String?
    var maxContextLength: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case state
        case maxContextLength = "max_context_length"
    }
}

private struct A1111NamedItem: Decodable {
    var name: String?
    var title: String?
    var modelName: String?

    var resolvedName: String {
        name ?? modelName ?? title ?? "Unknown"
    }

    enum CodingKeys: String, CodingKey {
        case name
        case title
        case modelName = "model_name"
    }
}

private struct A1111ExtensionItem: Decodable {
    var name: String
}

private struct ComfySystemStats: Decodable {
    var system: ComfySystem
    var devices: [ComfyDevice]
}

private struct ComfySystem: Decodable {
    var os: String?
    var comfyuiVersion: String?

    enum CodingKeys: String, CodingKey {
        case os
        case comfyuiVersion = "comfyui_version"
    }
}

private struct ComfyDevice: Decodable {
    var name: String
}

private struct ComfyNodeInfo: Decodable {}

private struct ComfyQueue: Decodable {
    var queueRunning: [ComfyQueueItem]
    var queuePending: [ComfyQueueItem]

    enum CodingKeys: String, CodingKey {
        case queueRunning = "queue_running"
        case queuePending = "queue_pending"
    }
}

private struct ComfyQueueItem: Decodable {}
