// Fleet/orchestrator/src/fleet.ts
//
// What: Fleet monitor — the orchestrator's view of machine health.
// Does: Owns one MachineConnection per configured machine, polls opencode
//       (via probe), LM Studio (/v1/models), and the diffusion service
//       (/api/health), caches MachineStatus, and broadcasts fleet.status
//       events when anything changes.
// Touches: MachineConnection, LM Studio + diffusion HTTP endpoints, SseHub.
// Touched by: sessions.ts (machine lookup / online checks) and api.ts.

import type { FleetEvent, MachineStatus, SseHub } from "@lucidity/shared";
import type { FleetConfig } from "./config.js";
import { MachineConnection, type OpencodeEventHandler } from "./opencode.js";

const POLL_INTERVAL_MS = 15_000;

export class FleetMonitor {
    readonly connections = new Map<string, MachineConnection>();
    private statuses = new Map<string, MachineStatus>();
    private diffusionOnline = false;
    private timer?: NodeJS.Timeout;
    private lastBroadcastJson = "";

    constructor(
        private readonly config: FleetConfig,
        private readonly hub: SseHub<FleetEvent>,
        onOpencodeEvent: OpencodeEventHandler,
    ) {
        for (const machine of config.machines) {
            this.connections.set(machine.id, new MachineConnection(machine, onOpencodeEvent));
            this.statuses.set(machine.id, {
                id: machine.id,
                name: machine.name,
                platform: machine.platform,
                opencodeOnline: false,
                models: [],
            });
        }
    }

    start(): void {
        void this.pollOnce();
        this.timer = setInterval(() => void this.pollOnce(), POLL_INTERVAL_MS);
    }

    stop(): void {
        if (this.timer) clearInterval(this.timer);
        for (const conn of this.connections.values()) conn.stop();
    }

    connection(machineId: string): MachineConnection | undefined {
        return this.connections.get(machineId);
    }

    status(machineId: string): MachineStatus | undefined {
        return this.statuses.get(machineId);
    }

    snapshot(): { machines: MachineStatus[]; diffusionOnline: boolean } {
        return {
            machines: this.config.machines
                .map((m) => this.statuses.get(m.id))
                .filter((s): s is MachineStatus => Boolean(s)),
            diffusionOnline: this.diffusionOnline,
        };
    }

    /** One poll cycle across every machine + the diffusion service, in parallel. */
    async pollOnce(): Promise<void> {
        await Promise.all([
            ...this.config.machines.map((m) => this.pollMachine(m.id)),
            this.pollDiffusion(),
        ]);
        this.broadcastIfChanged();
    }

    private async pollMachine(machineId: string): Promise<void> {
        const conn = this.connections.get(machineId);
        const status = this.statuses.get(machineId);
        if (!conn || !status) return;
        const probe = await conn.probe();
        status.opencodeOnline = probe.online;
        status.models = probe.models;
        status.lastError = probe.error;
        if (probe.online) status.lastSeenAt = Date.now();

        const lmPort = conn.machine.lmstudioPort;
        if (lmPort) {
            try {
                const res = await fetch(`http://${conn.machine.host}:${lmPort}/v1/models`, {
                    signal: AbortSignal.timeout(5_000),
                });
                const body = (await res.json()) as { data?: Array<{ id: string }> };
                status.lmstudioOnline = res.ok;
                status.lmstudioLoadedModels = (body.data ?? []).map((m) => m.id);
            } catch {
                status.lmstudioOnline = false;
                status.lmstudioLoadedModels = [];
            }
        }
    }

    private async pollDiffusion(): Promise<void> {
        try {
            const headers: Record<string, string> = {};
            if (this.config.token) headers["x-fleet-token"] = this.config.token;
            const res = await fetch(`${this.config.diffusionUrl}/api/health`, {
                headers,
                signal: AbortSignal.timeout(5_000),
            });
            const body = (await res.json()) as { comfyOnline?: boolean };
            // "Online" for the phone means the whole path works: service + ComfyUI.
            this.diffusionOnline = res.ok && body.comfyOnline === true;
        } catch {
            this.diffusionOnline = false;
        }
    }

    private broadcastIfChanged(): void {
        const snapshot = this.snapshot();
        const json = JSON.stringify(snapshot);
        if (json === this.lastBroadcastJson) return;
        this.lastBroadcastJson = json;
        this.hub.broadcast({ type: "fleet.status", ...snapshot });
    }
}
