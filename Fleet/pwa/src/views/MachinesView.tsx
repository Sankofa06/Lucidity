// Fleet/pwa/src/views/MachinesView.tsx
//
// What: The fleet tab — machine/model availability at a glance.
// Does: Per-machine cards (opencode + LM Studio state, loaded models, last
//       error), diffusion service state, manual refresh, and session adoption
//       for sessions started outside the orchestrator (e.g. in a TUI).
// Touches: api.ts.
// Touched by: App.tsx.

import { useState } from "react";
import { api } from "../api";
import type { FleetSnapshot, MachineStatus } from "../types";

export function MachinesView(props: { fleet: FleetSnapshot; onRefresh: () => void }) {
    const [refreshing, setRefreshing] = useState(false);
    const refresh = async () => {
        setRefreshing(true);
        try {
            await api.refreshFleet();
        } finally {
            props.onRefresh();
            setRefreshing(false);
        }
    };
    return (
        <div className="page">
            <header className="pagehead">
                <h1>Fleet</h1>
                <button onClick={refresh} disabled={refreshing}>
                    {refreshing ? "…" : "↻ Refresh"}
                </button>
            </header>
            {props.fleet.machines.map((m) => (
                <MachineCard key={m.id} machine={m} />
            ))}
            <div className="machinecard">
                <div className="machinecard-head">
                    <span className={props.fleet.diffusionOnline ? "dot on" : "dot off"} />
                    <b>Diffusion (ComfyUI)</b>
                </div>
                <p className="hint">
                    {props.fleet.diffusionOnline
                        ? "MCP diffusion server + ComfyUI reachable."
                        : "Unreachable — check the diffusion service and ComfyUI."}
                </p>
            </div>
        </div>
    );
}

function MachineCard({ machine }: { machine: MachineStatus }) {
    const [adopting, setAdopting] = useState(false);
    const [adopted, setAdopted] = useState<number>();
    const adopt = async () => {
        setAdopting(true);
        try {
            const res = await api.adoptSessions(machine.id);
            setAdopted(res.adopted);
        } catch {
            setAdopted(undefined);
        } finally {
            setAdopting(false);
        }
    };
    return (
        <div className="machinecard">
            <div className="machinecard-head">
                <span className={machine.opencodeOnline ? "dot on" : "dot off"} />
                <b>{machine.name}</b>
                <span className="hint">{machine.platform}</span>
            </div>
            <div className="machinecard-body">
                <div>
                    opencode: {machine.opencodeOnline ? "online" : "offline"}
                    {machine.lastSeenAt && !machine.opencodeOnline && (
                        <span className="hint">
                            {" "}
                            (last seen {new Date(machine.lastSeenAt).toLocaleString()})
                        </span>
                    )}
                </div>
                {machine.lmstudioOnline !== undefined && (
                    <div>
                        LM Studio: {machine.lmstudioOnline ? "online" : "offline"}
                        {machine.lmstudioLoadedModels &&
                            machine.lmstudioLoadedModels.length > 0 && (
                                <ul className="modellist">
                                    {machine.lmstudioLoadedModels.map((id) => (
                                        <li key={id}>{id}</li>
                                    ))}
                                </ul>
                            )}
                    </div>
                )}
                {machine.lastError && !machine.opencodeOnline && (
                    <p className="error">{machine.lastError}</p>
                )}
                {machine.opencodeOnline && (
                    <button onClick={adopt} disabled={adopting}>
                        {adopting
                            ? "…"
                            : adopted !== undefined
                              ? `Adopted ${adopted} session${adopted === 1 ? "" : "s"}`
                              : "Adopt existing sessions"}
                    </button>
                )}
            </div>
        </div>
    );
}
