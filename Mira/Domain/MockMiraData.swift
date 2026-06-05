// MockMiraData.swift
// Public-safe fixture data for Mira's first-build shell.
//
// The app and tests use these fake machines and routes only. Real user endpoint
// data belongs in ignored LocalDev files or runtime configuration.

import Foundation

enum MockMiraData {
    private static let projectID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let studioMachineID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let gpuMachineID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private static let lmEndpointID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private static let comfyEndpointID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    private static let chatRouteID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    private static let mediaRouteID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!

    static let projects = [
        MiraProject(
            id: projectID,
            name: "Mira Studio",
            summary: "Default project for chat, media, personas, and route experiments.",
            sessionCount: 3
        )
    ]

    static let inventory = InventorySnapshot(
        machines: [
            Machine(
                id: studioMachineID,
                name: "Example Studio Mac",
                hostDescription: "example-studio.tailnet.example",
                platform: "macOS",
                isUserConfigured: true
            ),
            Machine(
                id: gpuMachineID,
                name: "Example GPU Workstation",
                hostDescription: "example-gpu.tailnet.example",
                platform: "Windows",
                isUserConfigured: true
            )
        ],
        endpoints: [
            EngineEndpoint(
                id: lmEndpointID,
                machineID: studioMachineID,
                engine: .lmStudio,
                displayName: "LM Studio",
                port: 1234,
                health: .ready,
                metadataSummary: "18 chat-capable models, 2 vision routes"
            ),
            EngineEndpoint(
                id: comfyEndpointID,
                machineID: gpuMachineID,
                engine: .comfyUI,
                displayName: "ComfyUI",
                port: 8188,
                health: .available,
                metadataSummary: "Image, video, ControlNet, and workflow nodes"
            )
        ],
        routes: [
            SmartRoute(
                id: chatRouteID,
                friendlyName: "Studio Mac Chat",
                userAlias: "Daily Chat",
                machineID: studioMachineID,
                endpointID: lmEndpointID,
                modelName: "Example 30B Instruct",
                capabilities: [.text, .vision, .inspect, .reasoning],
                health: .ready,
                isPinned: true,
                isRecent: true
            ),
            SmartRoute(
                id: mediaRouteID,
                friendlyName: "GPU ComfyUI Media",
                userAlias: "Image Lab",
                machineID: gpuMachineID,
                endpointID: comfyEndpointID,
                modelName: "Example SDXL Workflow",
                capabilities: [.image, .video, .workflow, .inspect, .controlNet],
                health: .available,
                isPinned: true,
                isRecent: false
            )
        ],
        capturedAt: Date()
    )

    static let personas = [
        Persona(
            id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            name: "Mira Advisor",
            role: "Route and prompt advisor",
            character: nil,
            routeID: chatRouteID,
            mediaEnabled: true,
            memoryEnabled: true,
            webSearchEnabled: false
        )
    ]

    static let teams = [
        Team(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            name: "Studio Review",
            purpose: "Review prompts, compare model answers, and plan media runs.",
            personaIDs: personas.map(\.id)
        )
    ]

    static let workflows = [
        Workflow(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "Media Planning Draft",
            summary: "Advisor proposes routes, settings, and confirmation steps.",
            routeIDs: [mediaRouteID]
        )
    ]

    static let sources = [
        ModelSource(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            kind: .huggingFace,
            isKeyConfigured: false,
            summary: "Search, metadata, gated downloads, and model matching planned."
        ),
        ModelSource(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            kind: .civitAI,
            isKeyConfigured: false,
            summary: "Checkpoints, LoRAs, trigger words, previews, and licenses planned."
        )
    ]

    static let advisor = AdvisorConfiguration(
        defaultModelName: "Choose advisor route",
        requiresConfirmation: true,
        trustedModeEnabled: false
    )

    static let diagnostics = [
        DiagnosticEvent(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            title: "Route inventory ready",
            detail: "Mock inventory loaded from public-safe fixtures.",
            severity: .success,
            progress: 1.0
        ),
        DiagnosticEvent(
            id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            title: "Developer Mode available",
            detail: "Raw route and run details are hidden until enabled.",
            severity: .info,
            progress: nil
        )
    ]
}
