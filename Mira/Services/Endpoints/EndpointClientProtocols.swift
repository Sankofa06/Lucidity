// EndpointClientProtocols.swift
// Read-only endpoint service contracts for Mira's first engine integrations.
//
// Feature view models and tests depend on these protocols. Concrete clients
// perform URLSession work later and must keep mutations behind explicit APIs.

import Foundation

protocol LMStudioReadableClient: Sendable {
    func listModels(at address: EndpointAddress) async throws -> [EndpointModelSummary]
}

protocol Automatic1111ReadableClient: Sendable {
    func readInventory(at address: EndpointAddress) async throws -> ImageEndpointInventory
}

protocol ComfyUIReadableClient: Sendable {
    func readSystem(at address: EndpointAddress) async throws -> ComfyUISystemSummary
}

struct EndpointAddress: Hashable, Sendable {
    var host: String
    var port: Int
}

struct EndpointModelSummary: Identifiable, Hashable, Sendable {
    let id: String
    var displayName: String
    var modelType: String
    var contextLength: Int?
    var state: String?
}

struct ImageEndpointInventory: Hashable, Sendable {
    var checkpoints: [String]
    var loras: [String]
    var vaes: [String]
    var samplers: [String]
    var schedulers: [String]
    var extensions: [String]
}

struct ComfyUISystemSummary: Hashable, Sendable {
    var version: String?
    var operatingSystem: String?
    var devices: [String]
    var nodeCount: Int
    var queueRunning: Int
    var queuePending: Int
}
