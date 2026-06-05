# Mira Architecture

## Layers

Mira uses SwiftUI MVVM plus small service adapters. Domain models are pure value
types. Views render state. View models coordinate state and intent. Services do
side effects behind protocols.

Dependency direction:

`Domain -> Services -> Features -> App`

The first build keeps this structure as folders inside the app target. If the
project grows enough to justify separate Swift packages, these boundaries can
become package targets without changing names.

## Feature Areas

- `Chat`: transcript, composer, task picker, route picker, run cards.
- `Inspector`: contextual dashboard for route, machine, persona, diagnostics.
- `Settings`: organized settings hub and Developer Mode.
- `Personas`: persona and media persona editing.
- `Teams`: persona groups for group chat.
- `Projects`: containers for sessions and reusable objects.
- `Library`: local inventory and saved assets.
- `ModelSources`: Hugging Face and CivitAI source shells.
- `Machines`: configured machines and discovered endpoints.
- `Diagnostics`: status, logs, validation, timing, and operational signals.
- `DesignSystem`: tokens, theme, reusable surfaces, rail, cards, chips.

## Core Types

- `MiraProject`
- `ChatSession`
- `ChatMessage`
- `ChatTask`
- `Machine`
- `EngineEndpoint`
- `SmartRoute`
- `SmartRun`
- `RunStep`
- `InventorySnapshot`
- `ConfiguredMachineDraft`
- `MachinePortPreset`
- `InventoryRefreshState`
- `RouteValidator`
- `RunScheduler`
- `RunConcurrencyPolicy`
- `Persona`
- `Team`
- `Workflow`
- `ModelSource`
- `AdvisorConfiguration`
- `DiagnosticEvent`
- `ThemeTokens`

## Endpoint Policy

Real endpoint data is runtime/user configuration only. Public fixtures use fake
machines and example hostnames. Local smoke tests may use ignored files under
`LocalDev/`.

Manual machine settings are currently in-memory. `MachineSettingsViewModel`
validates drafts, normalizes expected ports, converts user-entered values into
`MachineProbeRequest`, and runs the existing `MachineInventoryService`,
`EndpointProbeService`, and `RouteHydrationService` pipeline. Chat, Inspector,
Machines, and Library all consume the refreshed `InventorySnapshot` from
`MiraAppState`.

## Background And Extensions

The first app target owns stable run IDs and extension-safe value models. Actual
App Intents, Live Activities, widgets, and host agents are later targets.
