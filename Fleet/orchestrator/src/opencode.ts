// Fleet/orchestrator/src/opencode.ts
//
// What: Per-machine connection to an `opencode serve` instance.
// Does: Wraps @opencode-ai/sdk's client for one machine, probes health +
//       available models, and maintains a reconnecting subscription to the
//       machine's /event SSE stream, forwarding events upward.
// Touches: opencode serve over the tailnet via the official SDK.
// Touched by: fleet.ts (probing) and sessions.ts (session calls + events).

import {
    createOpencodeClient,
    type Event as OpencodeEvent,
    type OpencodeClient,
} from "@opencode-ai/sdk/client";
import type { MachineConfig, MachineModel } from "@lucidity/shared";

export type OpencodeEventHandler = (machineId: string, event: OpencodeEvent) => void;

export class MachineConnection {
    readonly client: OpencodeClient;
    readonly baseUrl: string;
    private stopped = false;
    private subscribed = false;
    private retryMs = 1_000;

    constructor(
        readonly machine: MachineConfig,
        private readonly onEvent: OpencodeEventHandler,
        private readonly onSubscriptionStateChange?: (machineId: string, up: boolean) => void,
    ) {
        this.baseUrl = `http://${machine.host}:${machine.opencodePort}`;
        this.client = createOpencodeClient({ baseUrl: this.baseUrl });
    }

    /**
     * Probe the instance: reachable + which models its providers expose.
     * Uses /config/providers, which answers fast and doubles as model discovery.
     */
    async probe(): Promise<{ online: boolean; models: MachineModel[]; error?: string }> {
        try {
            const res = await this.client.config.providers({
                signal: AbortSignal.timeout(5_000),
            });
            if (!res.data) throw new Error(res.response.statusText || "no data");
            const models: MachineModel[] = res.data.providers.flatMap((provider) =>
                Object.values(provider.models).map((model) => ({
                    providerID: provider.id,
                    modelID: model.id,
                    name: model.name || model.id,
                    toolCall: Boolean((model as { tool_call?: boolean }).tool_call),
                    reasoning: Boolean((model as { reasoning?: boolean }).reasoning),
                })),
            );
            // A healthy probe is the trigger to (re)attach the event stream.
            this.ensureSubscribed();
            return { online: true, models };
        } catch (err) {
            return {
                online: false,
                models: [],
                error: err instanceof Error ? err.message : String(err),
            };
        }
    }

    /** Keep exactly one event-stream loop alive while the machine is reachable. */
    private ensureSubscribed(): void {
        if (this.subscribed || this.stopped) return;
        this.subscribed = true;
        void this.subscribeLoop();
    }

    private async subscribeLoop(): Promise<void> {
        while (!this.stopped) {
            try {
                const result = await this.client.event.subscribe();
                this.onSubscriptionStateChange?.(this.machine.id, true);
                this.retryMs = 1_000;
                for await (const event of result.stream) {
                    this.onEvent(this.machine.id, event as OpencodeEvent);
                }
            } catch {
                /* connection dropped; retry below */
            }
            this.onSubscriptionStateChange?.(this.machine.id, false);
            if (this.stopped) return;
            await new Promise((r) => setTimeout(r, this.retryMs));
            this.retryMs = Math.min(this.retryMs * 2, 30_000);
        }
    }

    stop(): void {
        this.stopped = true;
    }
}
