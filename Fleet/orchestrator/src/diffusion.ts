// Fleet/orchestrator/src/diffusion.ts
//
// What: Gateway from the orchestrator to the MCP diffusion service's REST side.
// Does: Proxies job creation/list/status/cancel and image bytes, and follows
//       the diffusion SSE stream, re-broadcasting job updates onto the
//       orchestrator's own event stream so the phone sees live progress.
// Touches: mcp-diffusion /api over the tailnet; SseHub.
// Touched by: api.ts routes; index.ts starts/stops the subscription.

import {
    subscribeSse,
    type DiffusionEvent,
    type DiffusionJob,
    type DiffusionParams,
    type FleetEvent,
    type SseHub,
    type SseSubscription,
} from "@lucidity/shared";
import type { FleetConfig } from "./config.js";

export class DiffusionGateway {
    private subscription?: SseSubscription;

    constructor(
        private readonly config: FleetConfig,
        private readonly hub: SseHub<FleetEvent>,
    ) {}

    start(): void {
        const url = new URL(`${this.config.diffusionUrl}/api/events`);
        if (this.config.token) url.searchParams.set("token", this.config.token);
        this.subscription = subscribeSse<DiffusionEvent>(url.toString(), (event) => {
            if (event.type === "job") {
                this.hub.broadcast({ type: "diffusion.job", job: event.job });
            }
        });
    }

    stop(): void {
        this.subscription?.close();
    }

    createJob(params: DiffusionParams): Promise<DiffusionJob> {
        return this.request<DiffusionJob>("POST", "/api/jobs", params);
    }

    listJobs(limit = 50): Promise<DiffusionJob[]> {
        return this.request<DiffusionJob[]>("GET", `/api/jobs?limit=${limit}`);
    }

    getJob(id: string): Promise<DiffusionJob> {
        return this.request<DiffusionJob>("GET", `/api/jobs/${encodeURIComponent(id)}`);
    }

    cancelJob(id: string): Promise<DiffusionJob> {
        return this.request<DiffusionJob>(
            "POST",
            `/api/jobs/${encodeURIComponent(id)}/cancel`,
        );
    }

    listWorkflows(): Promise<string[]> {
        return this.request<string[]>("GET", "/api/workflows");
    }

    /** Raw image fetch, piped by api.ts to the client. */
    async fetchImage(filename: string): Promise<Response> {
        return fetch(
            `${this.config.diffusionUrl}/api/images/${encodeURIComponent(filename)}`,
            { headers: this.headers(), signal: AbortSignal.timeout(30_000) },
        );
    }

    private async request<T>(method: string, pathname: string, body?: unknown): Promise<T> {
        const res = await fetch(this.config.diffusionUrl + pathname, {
            method,
            headers: {
                ...this.headers(),
                ...(body ? { "content-type": "application/json" } : {}),
            },
            body: body ? JSON.stringify(body) : undefined,
            signal: AbortSignal.timeout(30_000),
        });
        const json = (await res.json().catch(() => ({}))) as T & { error?: string };
        if (!res.ok) {
            throw new Error(json.error ?? `diffusion service error ${res.status}`);
        }
        return json;
    }

    private headers(): Record<string, string> {
        return this.config.token ? { "x-fleet-token": this.config.token } : {};
    }
}
