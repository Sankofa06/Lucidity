// RouteHydrationService.swift
// Converts read-only probe results into Mira inventory, routes, and diagnostics.
//
// Keeping this mapper separate lets UI state consume one InventorySnapshot
// whether data came from mocks, local config, Tailscale import, or persistence.

import Foundation

struct RouteHydrationService: RouteHydrating {
    func hydrate(from results: [MachineProbeResult]) -> InventorySnapshot {
        var machines: [Machine] = []
        var endpoints: [EngineEndpoint] = []
        var routes: [SmartRoute] = []

        for result in results {
            let machine = Machine(
                id: stableID("machine:\(result.request.host)"),
                name: result.request.machineName,
                hostDescription: result.request.host,
                platform: "Unknown",
                isUserConfigured: true
            )
            machines.append(machine)

            for summary in result.endpointSummaries {
                let endpointID = stableID("endpoint:\(summary.address.host):\(summary.address.port)")
                endpoints.append(
                    EngineEndpoint(
                        id: endpointID,
                        machineID: machine.id,
                        engine: summary.engine,
                        displayName: summary.engine.title,
                        port: summary.address.port,
                        health: summary.health,
                        metadataSummary: summary.metadataSummary
                    )
                )

                routes.append(contentsOf: routesForSummary(summary, machine: machine, endpointID: endpointID))
            }
        }

        return InventorySnapshot(
            machines: machines,
            endpoints: endpoints,
            routes: routes,
            capturedAt: Date()
        )
    }

    func diagnostics(from results: [MachineProbeResult]) -> [DiagnosticEvent] {
        results.flatMap { result in
            var events = result.diagnostics.map {
                DiagnosticEvent(
                    id: $0.id,
                    title: $0.title,
                    detail: $0.detail,
                    severity: $0.severity,
                    progress: nil
                )
            }

            if !result.endpointSummaries.isEmpty {
                events.append(
                    DiagnosticEvent(
                        id: stableID("diagnostic:\(result.request.host):ready"),
                        title: "\(result.request.machineName) inventory ready",
                        detail: "\(result.endpointSummaries.count) endpoint summaries hydrated.",
                        severity: .success,
                        progress: 1.0
                    )
                )
            }

            return events
        }
    }

    private func routesForSummary(
        _ summary: EndpointProbeSummary,
        machine: Machine,
        endpointID: UUID
    ) -> [SmartRoute] {
        switch summary.engine {
        case .lmStudio:
            return summary.modelSummaries.map { model in
                SmartRoute(
                    id: stableID("route:\(machine.hostDescription):\(summary.address.port):\(model.id)"),
                    friendlyName: "\(machine.name) \(summary.engine.title)",
                    userAlias: nil,
                    machineID: machine.id,
                    endpointID: endpointID,
                    modelName: model.displayName,
                    capabilities: capabilities(for: model),
                    health: summary.health,
                    isPinned: false,
                    isRecent: false
                )
            }
        case .automatic1111, .forge:
            return (summary.imageInventory?.checkpoints ?? ["Image Endpoint"]).map { checkpoint in
                SmartRoute(
                    id: stableID("route:\(machine.hostDescription):\(summary.address.port):\(checkpoint)"),
                    friendlyName: "\(machine.name) \(summary.engine.title)",
                    userAlias: nil,
                    machineID: machine.id,
                    endpointID: endpointID,
                    modelName: checkpoint,
                    capabilities: imageCapabilities(summary.imageInventory),
                    health: summary.health,
                    isPinned: false,
                    isRecent: false
                )
            }
        case .comfyUI:
            return [
                SmartRoute(
                    id: stableID("route:\(machine.hostDescription):\(summary.address.port):comfyui"),
                    friendlyName: "\(machine.name) ComfyUI",
                    userAlias: nil,
                    machineID: machine.id,
                    endpointID: endpointID,
                    modelName: summary.comfySummary?.version ?? "Workflow Endpoint",
                    capabilities: comfyCapabilities(summary.comfySummary),
                    health: summary.health,
                    isPinned: false,
                    isRecent: false
                )
            ]
        case .cloud, .modelSource:
            return []
        }
    }

    private func capabilities(for model: EndpointModelSummary) -> Set<RouteCapability> {
        var capabilities: Set<RouteCapability> = [.text, .inspect]
        if model.modelType.localizedCaseInsensitiveContains("vlm") {
            capabilities.insert(.vision)
        }
        return capabilities
    }

    private func imageCapabilities(_ inventory: ImageEndpointInventory?) -> Set<RouteCapability> {
        var capabilities: Set<RouteCapability> = [.image, .inspect]
        guard let inventory else { return capabilities }
        if !inventory.loras.isEmpty { capabilities.insert(.lora) }
        if inventory.extensions.contains(where: { $0.localizedCaseInsensitiveContains("animatediff") }) {
            capabilities.insert(.animation)
        }
        if inventory.extensions.contains(where: { $0.localizedCaseInsensitiveContains("controlnet") }) {
            capabilities.insert(.controlNet)
        }
        return capabilities
    }

    private func comfyCapabilities(_ summary: ComfyUISystemSummary?) -> Set<RouteCapability> {
        var capabilities: Set<RouteCapability> = [.image, .video, .workflow, .inspect]
        if summary?.nodeCount ?? 0 > 0 {
            capabilities.insert(.controlNet)
        }
        return capabilities
    }

    private func stableID(_ value: String) -> UUID {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012llX", hash & 0xFFFFFFFFFFFF)) ?? UUID()
    }
}
