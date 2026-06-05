// EndpointProbeService.swift
// Read-only probe service for LM Studio, A1111/Forge, and ComfyUI endpoints.
//
// The service only calls safe metadata endpoints and converts failures into
// diagnostics instead of mutating remote engines.

import Foundation

struct EndpointProbeService: EndpointProbing {
    var lmStudioClient: any LMStudioReadableClient
    var automatic1111Client: any Automatic1111ReadableClient
    var comfyUIClient: any ComfyUIReadableClient

    func probe(_ request: MachineProbeRequest) async -> MachineProbeResult {
        var summaries: [EndpointProbeSummary] = []
        var diagnostics: [ProbeDiagnostic] = []

        for port in request.expectedPorts {
            let address = EndpointAddress(host: request.host, port: port)
            switch port {
            case 1234:
                await probeLMStudio(address, summaries: &summaries, diagnostics: &diagnostics)
            case 7860...7865:
                await probeAutomatic1111(address, summaries: &summaries, diagnostics: &diagnostics)
            case 8188...8189:
                await probeComfyUI(address, summaries: &summaries, diagnostics: &diagnostics)
            default:
                diagnostics.append(
                    ProbeDiagnostic(
                        title: "Unsupported port \(port)",
                        detail: "Mira skipped \(request.machineName):\(port) because no read-only probe is registered.",
                        severity: .warning
                    )
                )
            }
        }

        return MachineProbeResult(
            request: request,
            endpointSummaries: summaries,
            diagnostics: diagnostics
        )
    }

    private func probeLMStudio(
        _ address: EndpointAddress,
        summaries: inout [EndpointProbeSummary],
        diagnostics: inout [ProbeDiagnostic]
    ) async {
        do {
            let models = try await lmStudioClient.listModels(at: address)
            summaries.append(
                EndpointProbeSummary(
                    address: address,
                    engine: .lmStudio,
                    health: models.isEmpty ? .available : .ready,
                    metadataSummary: "\(models.count) models",
                    modelSummaries: models
                )
            )
        } catch {
            diagnostics.append(failureDiagnostic(address: address, engine: .lmStudio, error: error))
        }
    }

    private func probeAutomatic1111(
        _ address: EndpointAddress,
        summaries: inout [EndpointProbeSummary],
        diagnostics: inout [ProbeDiagnostic]
    ) async {
        do {
            let inventory = try await automatic1111Client.readInventory(at: address)
            let engine: EngineKind = inventory.extensions.contains { $0.localizedCaseInsensitiveContains("forge") } ? .forge : .automatic1111
            summaries.append(
                EndpointProbeSummary(
                    address: address,
                    engine: engine,
                    health: inventory.checkpoints.isEmpty ? .available : .ready,
                    metadataSummary: "\(inventory.checkpoints.count) checkpoints · \(inventory.loras.count) LoRAs",
                    imageInventory: inventory
                )
            )
        } catch {
            diagnostics.append(failureDiagnostic(address: address, engine: .automatic1111, error: error))
        }
    }

    private func probeComfyUI(
        _ address: EndpointAddress,
        summaries: inout [EndpointProbeSummary],
        diagnostics: inout [ProbeDiagnostic]
    ) async {
        do {
            let summary = try await comfyUIClient.readSystem(at: address)
            summaries.append(
                EndpointProbeSummary(
                    address: address,
                    engine: .comfyUI,
                    health: .ready,
                    metadataSummary: "\(summary.nodeCount) nodes · \(summary.devices.count) devices",
                    comfySummary: summary
                )
            )
        } catch {
            diagnostics.append(failureDiagnostic(address: address, engine: .comfyUI, error: error))
        }
    }

    private func failureDiagnostic(address: EndpointAddress, engine: EngineKind, error: Error) -> ProbeDiagnostic {
        ProbeDiagnostic(
            title: "\(engine.title) probe failed",
            detail: "\(address.host):\(address.port) returned \(String(describing: error)).",
            severity: .warning
        )
    }
}
