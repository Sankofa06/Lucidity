// Fleet/mcp-diffusion/src/comfy.ts
//
// What: Minimal typed client for the ComfyUI HTTP + WebSocket API.
// Does: Submits prompt graphs, reads queue/history, downloads finished images,
//       and maintains a reconnecting WebSocket for live progress events.
// Touches: ComfyUI at config.comfyUrl (HTTP + /ws) over the tailnet.
// Touched by: jobs.ts (JobManager) exclusively.

import { randomUUID } from "node:crypto";
import WebSocket from "ws";
import type { ComfyGraph } from "./workflows.js";

/** Reference to an output image as ComfyUI reports it in history/executed. */
export interface ComfyImageRef {
    filename: string;
    subfolder: string;
    type: string; // "output" | "temp" | ...
}

export interface ComfyEvents {
    /** KSampler progress ticks. promptId may be missing on old builds. */
    onProgress?: (promptId: string | undefined, value: number, max: number) => void;
    /** A node finished and produced images (SaveImage etc.). */
    onExecuted?: (promptId: string, images: ComfyImageRef[]) => void;
    /** Whole prompt finished successfully (newer ComfyUI emits execution_success). */
    onSuccess?: (promptId: string) => void;
    onExecutionError?: (promptId: string, message: string) => void;
    onSocketStateChange?: (connected: boolean) => void;
}

export class ComfyClient {
    readonly clientId = randomUUID();
    private ws?: WebSocket;
    private wsRetryMs = 1_000;
    private closed = false;

    constructor(
        private readonly baseUrl: string,
        private readonly events: ComfyEvents = {},
    ) {}

    /** Open (and keep open) the progress WebSocket. Safe to call once at startup. */
    startSocket(): void {
        if (this.closed) return;
        const wsUrl =
            this.baseUrl.replace(/^http/, "ws") + `/ws?clientId=${this.clientId}`;
        const ws = new WebSocket(wsUrl);
        this.ws = ws;
        ws.on("open", () => {
            this.wsRetryMs = 1_000;
            this.events.onSocketStateChange?.(true);
        });
        ws.on("message", (data, isBinary) => {
            if (isBinary) return; // binary frames are preview JPEGs; skip
            try {
                this.handleSocketMessage(JSON.parse(data.toString()));
            } catch {
                /* non-JSON frame; ignore */
            }
        });
        const scheduleReconnect = () => {
            this.events.onSocketStateChange?.(false);
            if (this.closed) return;
            setTimeout(() => this.startSocket(), this.wsRetryMs);
            this.wsRetryMs = Math.min(this.wsRetryMs * 2, 30_000);
        };
        ws.on("close", scheduleReconnect);
        ws.on("error", () => ws.close());
    }

    stop(): void {
        this.closed = true;
        this.ws?.close();
    }

    private handleSocketMessage(msg: { type?: string; data?: any }): void {
        const d = msg.data ?? {};
        switch (msg.type) {
            case "progress":
                this.events.onProgress?.(d.prompt_id, d.value ?? 0, d.max ?? 0);
                break;
            case "executed":
                if (d.prompt_id && Array.isArray(d.output?.images)) {
                    this.events.onExecuted?.(d.prompt_id, d.output.images);
                }
                break;
            case "execution_success":
                if (d.prompt_id) this.events.onSuccess?.(d.prompt_id);
                break;
            case "execution_error":
                if (d.prompt_id) {
                    const message =
                        d.exception_message ?? d.exception_type ?? "execution error";
                    this.events.onExecutionError?.(d.prompt_id, String(message));
                }
                break;
            default:
                break;
        }
    }

    /** Submit a graph; returns ComfyUI's prompt id. */
    async submit(graph: ComfyGraph): Promise<string> {
        const res = await this.http("POST", "/prompt", {
            prompt: graph,
            client_id: this.clientId,
        });
        const body = (await res.json()) as {
            prompt_id?: string;
            error?: { message?: string; type?: string };
            node_errors?: Record<string, unknown>;
        };
        if (!res.ok || !body.prompt_id) {
            const detail =
                body.error?.message ??
                (body.node_errors ? JSON.stringify(body.node_errors) : res.statusText);
            throw new Error(`ComfyUI rejected prompt: ${detail}`);
        }
        return body.prompt_id;
    }

    /** Queue snapshot: prompt ids currently running and pending, in order. */
    async queue(): Promise<{ running: string[]; pending: string[] }> {
        const res = await this.http("GET", "/queue");
        const body = (await res.json()) as {
            queue_running?: unknown[][];
            queue_pending?: unknown[][];
        };
        // Each entry is [number, prompt_id, prompt, extra, outputs]; index 1 is the id.
        const ids = (rows?: unknown[][]) =>
            (rows ?? []).map((r) => String(r[1])).filter(Boolean);
        return { running: ids(body.queue_running), pending: ids(body.queue_pending) };
    }

    /** History record for a finished (or errored) prompt, if present yet. */
    async history(promptId: string): Promise<
        | {
              completed: boolean;
              error?: string;
              images: ComfyImageRef[];
          }
        | undefined
    > {
        const res = await this.http("GET", `/history/${promptId}`);
        const body = (await res.json()) as Record<
            string,
            {
                status?: { completed?: boolean; status_str?: string; messages?: unknown[][] };
                outputs?: Record<string, { images?: ComfyImageRef[] }>;
            }
        >;
        const entry = body[promptId];
        if (!entry) return undefined;
        const images = Object.values(entry.outputs ?? {}).flatMap(
            (o) => o.images ?? [],
        );
        const failed = entry.status?.status_str === "error";
        return {
            completed: Boolean(entry.status?.completed) && !failed,
            error: failed ? extractHistoryError(entry.status?.messages) : undefined,
            images,
        };
    }

    /** Download one output image's bytes. */
    async fetchImage(ref: ComfyImageRef): Promise<Buffer> {
        const params = new URLSearchParams({
            filename: ref.filename,
            subfolder: ref.subfolder ?? "",
            type: ref.type ?? "output",
        });
        const res = await this.http("GET", `/view?${params}`);
        if (!res.ok) throw new Error(`ComfyUI /view failed: ${res.status}`);
        return Buffer.from(await res.arrayBuffer());
    }

    /** Stop the currently running job. */
    async interrupt(): Promise<void> {
        await this.http("POST", "/interrupt");
    }

    /** Remove a pending (not yet running) prompt from the queue. */
    async deletePending(promptId: string): Promise<void> {
        await this.http("POST", "/queue", { delete: [promptId] });
    }

    /** GPU/OS stats; also the cheapest liveness probe. */
    async systemStats(): Promise<unknown> {
        const res = await this.http("GET", "/system_stats");
        if (!res.ok) throw new Error(`ComfyUI unreachable: ${res.status}`);
        return res.json();
    }

    private async http(method: string, pathname: string, body?: unknown): Promise<Response> {
        return fetch(this.baseUrl + pathname, {
            method,
            headers: body ? { "content-type": "application/json" } : undefined,
            body: body ? JSON.stringify(body) : undefined,
            signal: AbortSignal.timeout(30_000),
        });
    }
}

function extractHistoryError(messages: unknown[][] | undefined): string {
    // History "messages" is a list of [eventName, payload] tuples.
    for (const row of messages ?? []) {
        if (row[0] === "execution_error") {
            const payload = row[1] as { exception_message?: string } | undefined;
            if (payload?.exception_message) return payload.exception_message;
        }
    }
    return "execution error";
}
