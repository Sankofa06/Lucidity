// Fleet/shared/src/index.ts
//
// What: Shared wire types for the Lucidity Fleet services.
// Does: Defines the JSON shapes exchanged between the orchestrator, the MCP
//       diffusion server, and (mirrored by hand in pwa/src/types.ts) the PWA.
// Touches: Nothing at runtime here (sse.ts carries the only runtime helpers).
// Touched by: @lucidity/orchestrator and @lucidity/mcp-diffusion imports.

export * from "./sse.js";

/** Platform of a fleet machine; affects deploy scripts only, not the protocol. */
export type MachinePlatform = "macos" | "windows";

/** Static description of one machine in the fleet, from fleet config JSON. */
export interface MachineConfig {
    /** Stable identifier, e.g. "m5-macbook". Used as session pin + route key. */
    id: string;
    /** Human-readable name shown in the PWA. */
    name: string;
    /** Tailscale MagicDNS hostname or tailnet IP. Never a public address. */
    host: string;
    platform: MachinePlatform;
    /** Port of the `opencode serve` instance on this machine (default 4096). */
    opencodePort: number;
    /** Port of LM Studio's OpenAI-compatible server (default 1234), if present. */
    lmstudioPort?: number;
}

/** Runtime health snapshot of one machine, produced by the fleet monitor. */
export interface MachineStatus {
    id: string;
    name: string;
    platform: MachinePlatform;
    /** opencode serve reachable? */
    opencodeOnline: boolean;
    /** LM Studio server reachable? Undefined when the machine has no lmstudioPort. */
    lmstudioOnline?: boolean;
    /** Models advertised by this machine's opencode instance (via its providers). */
    models: MachineModel[];
    /** Model ids currently loaded in LM Studio (subset of models, best effort). */
    lmstudioLoadedModels?: string[];
    /** Last successful opencode contact, epoch ms. */
    lastSeenAt?: number;
    /** Last probe error, for the Machines screen. */
    lastError?: string;
}

/** One selectable model on a machine, flattened from opencode's provider list. */
export interface MachineModel {
    providerID: string;
    modelID: string;
    name: string;
    toolCall: boolean;
    reasoning: boolean;
}

/** A logical chat session as the orchestrator tracks it. */
export interface SessionRecord {
    /** Orchestrator-scoped id (same value as the opencode session id). */
    id: string;
    /** Machine the session is pinned to; it can only run there. */
    machineId: string;
    /** opencode's session id on that machine. */
    opencodeSessionId: string;
    title: string;
    /** Working directory on the pinned machine, if one was requested. */
    directory?: string;
    /** Set when this session was seeded from another session's transcript. */
    continuedFromSessionId?: string;
    /** Last model used, so the PWA can preselect it. */
    lastProviderID?: string;
    lastModelID?: string;
    archived: boolean;
    createdAt: number;
    updatedAt: number;
    /** True while the agent is working (between prompt and session.idle). */
    busy?: boolean;
}

/** A mirrored message. `parts` is opencode's parts array, stored verbatim. */
export interface MessageRecord {
    id: string;
    sessionId: string;
    role: "user" | "assistant";
    /** JSON of opencode Part[] (text, tool, reasoning, step-*, ...). */
    parts: unknown[];
    /** Error info for failed assistant turns, if any. */
    error?: unknown;
    createdAt: number;
    completedAt?: number;
}

/** Diffusion job lifecycle. */
export type DiffusionJobStatus =
    | "queued"
    | "running"
    | "completed"
    | "failed"
    | "canceled";

/** Parameters accepted for a txt2img generation. */
export interface DiffusionParams {
    prompt: string;
    negativePrompt?: string;
    width?: number;
    height?: number;
    steps?: number;
    cfg?: number;
    seed?: number;
    /** Sampler name as ComfyUI knows it, e.g. "euler". */
    sampler?: string;
    /** Checkpoint file name; server default when omitted. */
    checkpoint?: string;
    /** Named custom workflow (file in the workflows dir) instead of the builtin graph. */
    workflow?: string;
    batchSize?: number;
}

/** One generated image belonging to a job. */
export interface DiffusionImage {
    /** File name under the diffusion server's images dir; also its /api/images key. */
    filename: string;
    width?: number;
    height?: number;
}

/** A diffusion job as reported by the MCP diffusion server. */
export interface DiffusionJob {
    id: string;
    /** ComfyUI prompt id once submitted. */
    comfyPromptId?: string;
    status: DiffusionJobStatus;
    params: DiffusionParams;
    /** Sampler progress while running. */
    progress?: { value: number; max: number };
    /** 0-based position when queued behind other jobs, if known. */
    queuePosition?: number;
    images: DiffusionImage[];
    error?: string;
    /** Who asked: the phone via the orchestrator, or an agent via MCP. */
    source: "orchestrator" | "mcp";
    createdAt: number;
    updatedAt: number;
}

/** Events on the orchestrator's /api/events SSE stream (and PWA's contract). */
export type FleetEvent =
    | { type: "fleet.status"; machines: MachineStatus[]; diffusionOnline: boolean }
    | { type: "session.created"; session: SessionRecord }
    | { type: "session.updated"; session: SessionRecord }
    | { type: "session.deleted"; sessionId: string }
    | {
          type: "message.updated";
          sessionId: string;
          message: MessageRecord;
      }
    | {
          /** Streaming text delta for a part, so the PWA can render live tokens. */
          type: "message.part.delta";
          sessionId: string;
          messageId: string;
          partId: string;
          delta: string;
      }
    | { type: "session.idle"; sessionId: string }
    | { type: "session.error"; sessionId?: string; error?: unknown }
    | { type: "diffusion.job"; job: DiffusionJob };

/** Events on the diffusion server's /api/events SSE stream. */
export type DiffusionEvent = { type: "job"; job: DiffusionJob };

/** Health payload both services expose on /api/health. */
export interface HealthResponse {
    ok: boolean;
    service: string;
    version: string;
    uptimeSeconds: number;
}
