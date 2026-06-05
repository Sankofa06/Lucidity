// MachineInventoryService.swift
// Machine inventory providers for mock and local-development sources.
//
// Real user endpoints are never hardcoded. Local development can pass an
// ignored config file URL; app/demo mode falls back to public-safe fixtures.

import Foundation

struct MockMachineInventoryProvider: MachineInventoryProviding {
    func loadProbeRequests() async throws -> [MachineProbeRequest] {
        MockMiraData.inventory.machines.map { machine in
            let ports = MockMiraData.inventory.endpoints
                .filter { $0.machineID == machine.id }
                .compactMap(\.port)

            return MachineProbeRequest(
                machineName: machine.name,
                host: machine.hostDescription,
                expectedPorts: ports
            )
        }
    }
}

struct LocalFileMachineInventoryProvider: MachineInventoryProviding {
    var configURL: URL

    func loadProbeRequests() async throws -> [MachineProbeRequest] {
        let config = try LocalMachineConfigLoader.load(from: configURL)
        return config.machines.map {
            MachineProbeRequest(
                machineName: $0.name,
                host: $0.host,
                expectedPorts: $0.expectedPorts
            )
        }
    }
}

struct MachineInventoryService {
    var provider: any MachineInventoryProviding
    var prober: any EndpointProbing
    var hydrator: any RouteHydrating

    func refreshInventory() async throws -> MachineInventoryRefresh {
        let requests = try await provider.loadProbeRequests()
        var results: [MachineProbeResult] = []

        for request in requests {
            let result = await prober.probe(request)
            results.append(result)
        }

        return MachineInventoryRefresh(
            inventory: hydrator.hydrate(from: results),
            diagnostics: hydrator.diagnostics(from: results),
            probeResults: results
        )
    }
}

struct MachineInventoryRefresh: Hashable {
    var inventory: InventorySnapshot
    var diagnostics: [DiagnosticEvent]
    var probeResults: [MachineProbeResult]
}

struct MockEndpointProbeService: EndpointProbing {
    func probe(_ request: MachineProbeRequest) async -> MachineProbeResult {
        let machine = MockMiraData.inventory.machines.first { $0.name == request.machineName }
        let summaries = MockMiraData.inventory.endpoints
            .filter { endpoint in
                endpoint.machineID == machine?.id && endpoint.port.map(request.expectedPorts.contains) == true
            }
            .map { endpoint in
                let address = EndpointAddress(host: request.host, port: endpoint.port ?? 0)
                return EndpointProbeSummary(
                    address: address,
                    engine: endpoint.engine,
                    health: endpoint.health,
                    metadataSummary: endpoint.metadataSummary,
                    modelSummaries: mockModels(for: endpoint),
                    imageInventory: mockImageInventory(for: endpoint),
                    comfySummary: mockComfySummary(for: endpoint)
                )
            }

        return MachineProbeResult(
            request: request,
            endpointSummaries: summaries,
            diagnostics: []
        )
    }

    private func mockModels(for endpoint: EngineEndpoint) -> [EndpointModelSummary] {
        guard endpoint.engine == .lmStudio else { return [] }
        return MockMiraData.inventory.routes
            .filter { $0.endpointID == endpoint.id }
            .map {
                EndpointModelSummary(
                    id: $0.modelName,
                    displayName: $0.modelName,
                    modelType: $0.capabilities.contains(.vision) ? "vlm" : "llm",
                    contextLength: nil,
                    state: endpoint.health.title
                )
            }
    }

    private func mockImageInventory(for endpoint: EngineEndpoint) -> ImageEndpointInventory? {
        guard endpoint.engine == .automatic1111 || endpoint.engine == .forge else { return nil }
        return ImageEndpointInventory(
            checkpoints: MockMiraData.inventory.routes.filter { $0.endpointID == endpoint.id }.map(\.modelName),
            loras: ["example-lora"],
            vaes: [],
            samplers: ["Euler"],
            schedulers: ["karras"],
            extensions: ["controlnet"]
        )
    }

    private func mockComfySummary(for endpoint: EngineEndpoint) -> ComfyUISystemSummary? {
        guard endpoint.engine == .comfyUI else { return nil }
        return ComfyUISystemSummary(
            version: "fixture",
            operatingSystem: "fixture",
            devices: ["Example GPU"],
            nodeCount: 2,
            queueRunning: 0,
            queuePending: 0
        )
    }
}
