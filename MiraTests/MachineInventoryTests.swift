// MachineInventoryTests.swift
// Tests for Mira machine inventory loading, probing, hydration, and state update.
//
// These tests use fake hosts and stub endpoint clients so no private endpoint
// data or network access enters the committed suite.

import Testing
@testable import Mira

struct MachineInventoryTests {
    @Test func mockProviderLoadsPublicSafeRequests() async throws {
        let provider = MockMachineInventoryProvider()

        let requests = try await provider.loadProbeRequests()

        #expect(requests.isEmpty == false)
        #expect(requests.allSatisfy { $0.host.contains("example") })
    }

    @Test func endpointProberSummarizesKnownPorts() async {
        let prober = EndpointProbeService(
            lmStudioClient: StubLMStudioClient(),
            automatic1111Client: StubA1111Client(),
            comfyUIClient: StubComfyClient()
        )
        let request = MachineProbeRequest(
            machineName: "Example GPU",
            host: "example-gpu.tailnet.example",
            expectedPorts: [1234, 7860, 8188, 5000]
        )

        let result = await prober.probe(request)

        #expect(result.endpointSummaries.count == 3)
        #expect(result.diagnostics.contains { $0.title.contains("Unsupported port") })
    }

    @Test func hydratorCreatesRoutesAndDiagnostics() async {
        let prober = EndpointProbeService(
            lmStudioClient: StubLMStudioClient(),
            automatic1111Client: StubA1111Client(),
            comfyUIClient: StubComfyClient()
        )
        let request = MachineProbeRequest(
            machineName: "Example GPU",
            host: "example-gpu.tailnet.example",
            expectedPorts: [1234, 7860, 8188]
        )
        let result = await prober.probe(request)
        let hydrator = RouteHydrationService()

        let inventory = hydrator.hydrate(from: [result])
        let diagnostics = hydrator.diagnostics(from: [result])

        #expect(inventory.machines.count == 1)
        #expect(inventory.endpoints.count == 3)
        #expect(inventory.routes.contains { $0.capabilities.contains(.text) })
        #expect(inventory.routes.contains { $0.capabilities.contains(.image) })
        #expect(diagnostics.contains { $0.severity == .success })
    }

    @MainActor
    @Test func appStateAcceptsInventoryRefresh() async {
        let refresh = MachineInventoryRefresh(
            inventory: MockMiraData.inventory,
            diagnostics: MockMiraData.diagnostics,
            probeResults: [
                MachineProbeResult(
                    request: MachineProbeRequest(
                        machineName: "Example",
                        host: "example.tailnet.example",
                        expectedPorts: [1234]
                    ),
                    endpointSummaries: [],
                    diagnostics: []
                )
            ]
        )
        let state = MiraAppState()

        state.applyInventoryRefresh(refresh)

        #expect(state.probeResults.count == 1)
        #expect(state.selectedRoute != nil)
    }
}

private struct StubLMStudioClient: LMStudioReadableClient {
    func listModels(at address: EndpointAddress) async throws -> [EndpointModelSummary] {
        [
            EndpointModelSummary(
                id: "example-chat",
                displayName: "Example Chat",
                modelType: "llm",
                contextLength: 4096,
                state: "ready"
            )
        ]
    }
}

private struct StubA1111Client: Automatic1111ReadableClient {
    func readInventory(at address: EndpointAddress) async throws -> ImageEndpointInventory {
        ImageEndpointInventory(
            checkpoints: ["example-checkpoint"],
            loras: ["example-lora"],
            vaes: [],
            samplers: ["Euler"],
            schedulers: ["karras"],
            extensions: ["controlnet", "animatediff"]
        )
    }
}

private struct StubComfyClient: ComfyUIReadableClient {
    func readSystem(at address: EndpointAddress) async throws -> ComfyUISystemSummary {
        ComfyUISystemSummary(
            version: "fixture",
            operatingSystem: "fixture",
            devices: ["Example GPU"],
            nodeCount: 42,
            queueRunning: 0,
            queuePending: 0
        )
    }
}
