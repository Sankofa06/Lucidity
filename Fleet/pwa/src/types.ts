// Fleet/pwa/src/types.ts
//
// What: Wire types for the orchestrator API, mirrored by hand.
// Does: Keeps the PWA build self-contained (no workspace build coupling);
//       must stay in sync with Fleet/shared/src/index.ts.
// Touches: nothing at runtime.
// Touched by: every PWA module.

export interface MachineModel {
    providerID: string;
    modelID: string;
    name: string;
    toolCall: boolean;
    reasoning: boolean;
}

export interface MachineStatus {
    id: string;
    name: string;
    platform: "macos" | "windows";
    opencodeOnline: boolean;
    lmstudioOnline?: boolean;
    models: MachineModel[];
    lmstudioLoadedModels?: string[];
    lastSeenAt?: number;
    lastError?: string;
}

export interface FleetSnapshot {
    machines: MachineStatus[];
    diffusionOnline: boolean;
}

export interface SessionRecord {
    id: string;
    machineId: string;
    opencodeSessionId: string;
    title: string;
    directory?: string;
    continuedFromSessionId?: string;
    lastProviderID?: string;
    lastModelID?: string;
    archived: boolean;
    createdAt: number;
    updatedAt: number;
    busy?: boolean;
}

export interface MessagePart {
    id?: string;
    type?: string;
    text?: string;
    tool?: string;
    state?: { status?: string; title?: string };
    [key: string]: unknown;
}

export interface MessageRecord {
    id: string;
    sessionId: string;
    role: "user" | "assistant";
    parts: MessagePart[];
    error?: unknown;
    createdAt: number;
    completedAt?: number;
}

export type DiffusionJobStatus = "queued" | "running" | "completed" | "failed" | "canceled";

export interface DiffusionParams {
    prompt: string;
    negativePrompt?: string;
    width?: number;
    height?: number;
    steps?: number;
    cfg?: number;
    seed?: number;
    workflow?: string;
    [key: string]: unknown;
}

export interface DiffusionJob {
    id: string;
    status: DiffusionJobStatus;
    params: DiffusionParams;
    progress?: { value: number; max: number };
    queuePosition?: number;
    images: { filename: string }[];
    error?: string;
    source: "orchestrator" | "mcp";
    createdAt: number;
    updatedAt: number;
}

export type FleetEvent =
    | ({ type: "fleet.status" } & FleetSnapshot)
    | { type: "session.created"; session: SessionRecord }
    | { type: "session.updated"; session: SessionRecord }
    | { type: "session.deleted"; sessionId: string }
    | { type: "message.updated"; sessionId: string; message: MessageRecord }
    | {
          type: "message.part.delta";
          sessionId: string;
          messageId: string;
          partId: string;
          delta: string;
      }
    | { type: "session.idle"; sessionId: string }
    | { type: "session.error"; sessionId?: string; error?: unknown }
    | { type: "diffusion.job"; job: DiffusionJob };
