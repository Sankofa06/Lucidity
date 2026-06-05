# Lucidity — Product Requirements Document

> **Status:** Draft · **Owner:** mdwilliams1989 · **Date:** 2026-06-05
> **Tagline:** Better LM Manager Pro — one calm surface for every AI workload across all your machines.

---

## 1. Problem

AI workloads are scattered. Chat models run in LM Studio or Ollama on one box,
image and video pipelines run in ComfyUI or Automatic1111 on a GPU machine, and
the best frontier models live behind cloud APIs. Each has its own app, port, and
quirks. There is no single place to talk to all of them, route work to the right
machine, and let long jobs finish on their own.

## 2. Vision

Lucidity is a **unified control surface for AI** across a person's own fleet of
machines. The phone or Mac is a **client** that drives a **mesh of compute** —
Macs and Windows/Linux GPU boxes — discovered over Tailscale. Lucidity also runs
its own on-device inference. Everything is reachable, observable, and composable
from one calm, modular interface, with a chat window as the universal entry point.

## 3. Goals & non-goals

**Goals**
- One surface to drive local engines, cloud APIs, and on-device inference.
- A distributed mesh where models can live on any machine and run concurrently.
- Long-running jobs (e.g. 48 images from one prompt) finish in the background
  and survive the client disconnecting.
- Bring-your-own-keys for cloud and tooling providers, stored securely.
- Optional, free sync of personal data across the user's Apple devices.
- A foundation modular enough that new workflows slot in without rework.

**Non-goals (for now)**
- Multi-tenant / team-cloud hosting. This is personal infrastructure.
- A hosted backend we have to operate. Sync rides on CloudKit.
- Replacing the engines themselves — Lucidity orchestrates, it doesn't reimplement.

## 4. Users

- **The power user / builder** running several AI tools across personal machines
  who wants one remote control instead of five apps and a pile of ports.
- **The mobile operator** who wants to kick off heavy generation from a phone and
  walk away while a desktop GPU does the work.

## 5. Experience principles

- **Calm and modular.** Small, focused screens; nothing overwhelming.
- **One entry point.** A chat surface is the universal way to start any workload.
- **Background by default.** Heavy work runs to completion without babysitting.
- **Your keys, your machines.** Local-first, private, no required cloud account.

---

## 6. Core concepts (shared vocabulary)

- **Node** — a machine in the mesh (Mac, PC, GPU box), identified via Tailscale.
- **Host** — the Lucidity service running on a node; advertises capabilities,
  runs jobs, and normalizes each engine's quirks behind one protocol.
- **Capability connector** — a per-engine helper on a Host that auto-discovers a
  live engine by probing its port (LM Studio `:1234`, A1111 `:7860`,
  ComfyUI `:8188`, Ollama `:11434`). A dedicated helper per machine/engine so
  nodes never interfere and run concurrently.
- **Provider** — a cloud or local model endpoint (Anthropic, OpenAI, Gemini,
  Qwen, Atlas, an OpenRouter-style aggregator, and custom plug-ins).
- **Engine** — anything that produces output behind one unified interface:
  embedded MLX, embedded llama.cpp, or a remote engine reached through a Host.
- **Job** — a unit of work (chat, image batch, video render) that is durable,
  observable, and resumable.
- **Persona / Team / Workflow** — reusable configurations the user composes and
  (optionally) syncs. Personas bundle a default target + parameters; Teams group
  personas; Workflows capture saved ComfyUI/A1111 graphs + parameters.

---

## 7. Requirements

### 7.1 Functional
- **Unified chat** that can initiate any workflow from one window: local LM Studio
  chat, cloud chat, and A1111 + ComfyUI image/video.
- **Mesh discovery** via Tailscale; each machine exposes capabilities by port;
  concurrent, non-interfering execution across machines.
- **Background jobs** with live progress (and thumbnails for image batches) that
  stream back into the chat transcript and survive client disconnects.
- **Embedded inference** on-device, supporting both MLX and llama.cpp/GGUF
  behind one interface.
- **Provider management** — Anthropic, OpenAI, Gemini, Qwen, Atlas at launch; an
  OpenRouter-style aggregator and a generic custom-provider path for new engines
  (e.g. an on-device "ovi").
- **Secure key storage** for model providers and tooling (Tailscale, ComfyUI,
  CivitAI, HuggingFace) in the system keychain.
- **Optional sync** of personas, teams, workflows, and chat history across the
  user's Apple devices, toggleable on/off.

### 7.2 Non-functional
- **Platforms:** iOS + macOS clients; Host service on macOS first, cross-OS later.
- **Architecture:** MVVM / Clean Swift, deeply modular, very small single-purpose
  files, natural-language naming with minimal acronyms, easy to search.
- **Privacy:** local-first; no required account; secrets stay on-device.
- **Resilience:** jobs live on the Host so phone limits never kill long work;
  graceful handling when a node is unreachable, with direct-IP fallback.
- **Concurrency:** machines and engines operate in isolation (one helper each)
  so heavy work on one box never blocks another.

---

## 8. First milestone — the vertical slice

A single, rock-solid, hyper-modular **Chat window** that can drive **everything**
from one surface:
- chat with a **local LM Studio** model,
- chat with a **cloud** provider using the user's key,
- generate images/video via **Automatic1111** and **ComfyUI**,
- with multi-image batches running as **background jobs** whose progress and
  results appear inline in the conversation.

This proves the end-to-end spine — providers, connectors, jobs, and the chat
surface — before broader workflows are layered on.

**Minimum to make it real:** the chat feature module; cloud providers for
Anthropic and OpenAI-compatible (covers OpenAI + Qwen); the LM Studio connector;
the A1111 connector (single image inline) and ComfyUI connector (direct
`/prompt` + websocket progress into an inline job card); keychain key entry; and
local-only persistence of sessions and messages. Jobs may run client-resident in
this phase before the Host daemon exists.

---

## 9. Technical architecture

### 9.1 Layering and modules

One Swift Package Manager workspace, many tiny targets. Strict dependency
direction — **Foundation ← Domain ← Services ← Features ← App** — so the compiler
enforces boundaries. Domain targets hold protocols + value types only (no UI, no
networking). Concretes only meet at the composition root.

**Foundation (no dependencies)**
- `LucidityCoreModels` — value types: `ChatMessage`, `ChatRole`,
  `GenerationParameters`, `ModelDescriptor`, `Identifier`.
- `LucidityErrors` — shared typed error enums.
- `LucidityConcurrencyHelpers` — async-stream builders, throttling, cancellation.

**Domain (protocols + value types only)**
- `InferenceEngineInterface`, `ChatProviderInterface`,
  `CapabilityConnectorInterface`, `HostServiceInterface`, `JobModelInterface`,
  `SecretsInterface`, `PersistenceInterface`.

**Services / adapters (implement domain protocols)**
- Inference: `EmbeddedInferenceMLX`, `EmbeddedInferenceLlamaCpp`,
  `RemoteInferenceClient` (presents a remote Host as a normal engine).
- Cloud: `CloudProviderAnthropic`, `CloudProviderOpenAICompatible` (shared SSE
  engine reused by OpenAI/Qwen/custom), `CloudProviderGemini`,
  `ImageProviderAtlas`; plus `ProviderAggregator` (OpenRouter-style fan-in) and
  `CustomProviderPlugin` (config-driven drop-in, e.g. "ovi").
- Connectors: `ConnectorLMStudio`, `ConnectorAutomatic1111`, `ConnectorComfyUI`,
  `ConnectorOllama`.
- Mesh/transport: `TailscaleDiscovery`, `HostTransportClient`.
- Storage/secrets: `PersistenceSwiftData`, `CloudKitSyncCoordinator`,
  `KeychainSecretStore`.

**Features (SwiftUI, MVVM/Clean)**
- `ChatFeature` (the slice), `SettingsFeature` (providers/keys/sync toggle),
  `DesignSystem`; `MeshFeature` and `JobsFeature` arrive in later phases.

**App / executables**
- `LucidityApp` (iOS + macOS) — composition root; a tiny `Dependencies`
  container wires concretes into feature protocols.
- `LucidityHost` (macOS executable, cross-OS aspirational) — runs connectors
  concurrently, owns the durable job queue, serves the wire protocol.

### 9.2 Core protocol sketches

```swift
protocol InferenceEngine: Sendable {            // embedded MLX, llama.cpp, remote
    var descriptor: ModelDescriptor { get }
    func loadIfNeeded() async throws
    func streamCompletion(_ request: InferenceRequest) -> AsyncThrowingStream<TokenChunk, Error>
    func cancelActiveGeneration() async
}

protocol ChatProvider: Sendable {               // cloud + local chat
    var descriptor: ProviderDescriptor { get }
    var capabilities: Set<ProviderCapability> { get }   // .textChat, .vision, .imageGeneration
    func streamChat(_ request: ChatRequest) -> AsyncThrowingStream<ChatEvent, Error>
}
enum ChatEvent: Sendable { case token(String), toolCall(ToolCall), finished(StopReason) }

protocol CapabilityConnector: Sendable {        // one per engine; probes a machine
    var engineName: String { get }
    var defaultPort: Int { get }
    func probe(host: TailscaleAddress) async -> DiscoveredEngine?   // nil if not live
    func makeEngine(for discovered: DiscoveredEngine) -> InferenceEngine
}

protocol HostService: Sendable {                // the per-machine Lucidity Host
    func liveEngines() async -> [DiscoveredEngine]
    func submitJob(_ kind: JobKind) async throws -> Job.Identifier
    func events(for job: Job.Identifier) -> AsyncStream<HostEvent>   // progress/tokens
    func resume(_ job: Job.Identifier) async throws
}

struct Job: Sendable, Identifiable {            // durable, observable, resumable
    let id: Identifier
    var kind: JobKind                           // .chatCompletion, .imageBatch(count:), .videoRender
    var status: JobStatus                       // queued, running, paused, completed, failed, cancelled
    var progress: JobProgress
    var checkpoint: JobCheckpoint?              // enough state to resume after restart
}
```

### 9.3 The chat slice in detail

One `ChatView` → one `ChatViewModel` → one `ChatSessionController` (use case) →
a `GenerationRouter` that dispatches to backends behind two protocols
(`ChatProvider` for text; `JobKind`-driven `HostService` for image/video).

Flow:
1. `ChatComposerView` submits text plus a chosen **target** (from a `@`-style
   picker or a persona default): local LM Studio, cloud provider, A1111, ComfyUI.
2. `ChatViewModel` appends the user message; calls `ChatSessionController.send`.
3. `GenerationRouter` maps target → backend:
   - **LM Studio** → connector exposes a `ChatProvider` (OpenAI-compatible SSE);
     tokens stream into a placeholder assistant message.
   - **Cloud** → the matching `CloudProvider.streamChat`; tokens append live.
   - **A1111** → `txt2img`; single image awaited inline, a batch becomes a Job.
   - **ComfyUI** → POST workflow JSON to `/prompt` with a `client_id`, subscribe
     to the websocket; `executing`/`progress` map to `JobProgress`.
4. For background work, the router calls `submitJob(.imageBatch(...))`; the
   controller inserts an assistant **job-card message** holding the job id and
   subscribes to `events(for:)`. Each `.progress`/`.assetReady` updates that same
   message (progress bar; thumbnails appear as each image lands). Because the job
   lives on the Host, closing the client doesn't kill it; on relaunch the client
   re-subscribes by id and resumes from the checkpoint.

Files stay tiny and single-purpose: `ChatView`, `ChatTranscriptView`,
`MessageBubbleView`, `JobCardView`, `ChatComposerView`, `TargetPickerView`,
`ChatViewModel`, `ChatSessionController`, `GenerationRouter`, `ChatMessageDraft`.
View = rendering only; ViewModel = observable UI state; Controller = use cases;
Router = backend selection.

### 9.4 Mesh & networking

- **Discovery:** `TailscaleDiscovery` enumerates tailnet peers (`tailscale
  status --json` or the Tailscale REST API with a stored key) and probes each
  peer's Host control port. Tailscale supplies stable IPs + identity, so there's
  no custom auth or NAT traversal.
- **Per-machine concurrency:** each Host runs a `ConnectorSupervisor` actor that
  owns one child task per connector and probes ports concurrently. A dedicated
  helper actor per engine isolates state; a `JobRunner` actor runs jobs with
  bounded concurrency — matching the "dedicated helper, no interference" rule.
- **Transport (client ↔ Host):** a small JSON protocol over two channels — REST
  for request/response (list engines, submit/cancel job, fetch snapshot) and a
  WebSocket for streaming a framed `HostEvent` enum (`.token`,
  `.progress(completed,total,step)`, `.assetReady(url)`, `.statusChanged`,
  `.error`).
- **Dialect normalization:** the Host translates each engine's native protocol
  into the common `HostEvent`. ComfyUI's websocket (`executing` with a null node
  = done, `progress` = sampler step) and A1111's polled `/sdapi/v1/progress` both
  surface identically, so the client never speaks a tool's native dialect.
- `RemoteInferenceClient` presents a Host as a normal engine/provider — embedded
  MLX and a remote ComfyUI box look identical to the router.

### 9.5 Persistence & sync

- **SwiftData** for client storage: native to iOS/macOS, first-class CloudKit
  mirroring, low ceremony. `@Model` classes live only in `PersistenceSwiftData`
  and map to `LucidityCoreModels` value types at the boundary, so domain and
  features never import SwiftData and a second backend is just another
  `PersistenceInterface` implementation.
- **Entities:** `StoredChatSession` ↔ `[StoredMessage]`; `StoredMessage` (role,
  text, attachments, optional job id); `StoredPersona`, `StoredTeam`,
  `StoredWorkflow` (graph JSON + params); `StoredJobRecord` (client mirror of a
  Host job); `StoredNode` (Tailscale name, last-seen engines).
- **CloudKit rules baked in:** no unique constraints, all relationships optional
  with inverses, no ordered relations, add-only migrations post-launch — use
  synthetic UUIDs and dedupe in app logic. `CloudKitSyncCoordinator` chooses
  local-only vs private-CloudKit at store construction, so sync is a pure toggle.
- The **Host's** durable job store is **separate** (SQLite-backed in the Host),
  not SwiftData, since the Host is headless and needs robust crash-resume that's
  independent of CloudKit.
- **Secrets** for all providers and tooling live in the keychain via one
  `SecretAccount` enum; secrets are device-local and not synced.

---

## 10. Phased roadmap

1. **Chat vertical slice** — the milestone in §8 (jobs run client-side at first).
2. **Host daemon + mesh** — Tailscale discovery, per-machine connectors behind
   the Host, a node/engine browser (`MeshFeature`).
3. **Durable jobs at scale** — persistent queue, checkpoints, crash-resume, large
   batches surviving disconnect; a jobs dashboard (`JobsFeature`).
4. **Embedded inference** — MLX, then llama.cpp/GGUF, behind the unified engine
   interface; model download/management (CivitAI/HuggingFace browsing).
5. **Sync** — CloudKit sync of personal data, toggleable, with conflict handling.
6. **More providers & workflows** — Gemini, Atlas, the aggregator, custom
   plug-ins ("ovi"), saved workflows, and video — plus further workflow ideas
   the owner wants to add over time.

---

## 11. Key risks & decisions to flag

- **Cross-OS Host in Swift** — Windows/Linux GPU boxes mean no MLX (Apple-only)
  and weaker Swift-on-Windows server support. Keep Host logic pure-Swift on a
  server framework (runs on Linux), gate Apple-only engines behind
  `#if canImport`; likely ship a Linux Host first and Windows via WSL.
- **MLX vs llama.cpp packaging** — MLX-Swift is Apple-silicon-only; llama.cpp
  needs a C++ interop target and per-platform binaries. Separate targets behind
  the engine protocol so neither's build complexity leaks.
- **ComfyUI websocket** — handle binary preview frames and mid-job reconnects
  (re-attach by prompt id). A1111 has no progress socket → poll and normalize.
- **iOS background limits** — the core reason heavy jobs live on the Host, not
  the device; long batches aren't run on iOS.
- **CloudKit + SwiftData constraints** — freeze the schema carefully before
  enabling sync; dedupe in app logic, not via DB constraints.
- **Provider streaming divergence** — Anthropic, OpenAI/Qwen, and Gemini each
  stream differently; isolate each adapter behind the common `ChatEvent`.
- **Tailscale dependency** — graceful "Host unreachable" UX and direct-IP
  fallback when the tailnet is down.

---

## 12. Open questions

- A second sync option to complement CloudKit (to be discussed).
- Whether MLX or llama.cpp ships first when we sequence embedded inference.
- The full set of additional workflows the owner wants beyond the first slice.

## 13. Success criteria

A user can, from one chat window, complete a text chat (local and cloud) and kick
off an image batch on a remote machine that finishes in the background and shows
up in the conversation — without ever touching an underlying tool's own UI.
