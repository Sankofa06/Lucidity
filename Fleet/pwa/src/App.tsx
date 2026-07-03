// Fleet/pwa/src/App.tsx
//
// What: App shell — hash routing, global state, tab bar, connection banner.
// Does: Holds fleet/sessions/jobs state fed by REST + SSE, routes between
//       Chat, Images, and Machines views, and exposes a settings sheet for
//       the optional fleet token.
// Touches: api.ts, events.ts, all views.
// Touched by: main.tsx.

import { useCallback, useEffect, useMemo, useState } from "react";
import { api, getToken, setToken } from "./api";
import { onConnectionState, onFleetEvent, reconnectEvents } from "./events";
import type { DiffusionJob, FleetSnapshot, SessionRecord } from "./types";
import { ChatView } from "./views/ChatView";
import { ImagesView } from "./views/ImagesView";
import { MachinesView } from "./views/MachinesView";

type Route =
    | { tab: "chat"; sessionId?: string }
    | { tab: "images" }
    | { tab: "machines" };

function parseHash(): Route {
    const hash = window.location.hash.replace(/^#\/?/, "");
    const [tab, id] = hash.split("/");
    if (tab === "images") return { tab: "images" };
    if (tab === "machines") return { tab: "machines" };
    return { tab: "chat", sessionId: id || undefined };
}

export function App() {
    const [route, setRoute] = useState<Route>(parseHash);
    const [fleet, setFleet] = useState<FleetSnapshot>({ machines: [], diffusionOnline: false });
    const [sessions, setSessions] = useState<SessionRecord[]>([]);
    const [jobs, setJobs] = useState<DiffusionJob[]>([]);
    const [connected, setConnected] = useState(false);
    const [showSettings, setShowSettings] = useState(false);

    useEffect(() => {
        const onHash = () => setRoute(parseHash());
        window.addEventListener("hashchange", onHash);
        return () => window.removeEventListener("hashchange", onHash);
    }, []);

    const refresh = useCallback(() => {
        api.fleet().then(setFleet).catch(() => {});
        api.sessions().then(setSessions).catch(() => {});
        api.diffusionJobs().then(setJobs).catch(() => {});
    }, []);

    useEffect(refresh, [refresh]);

    // SSE keeps state live; a fresh connection also triggers a full refresh so
    // anything missed while the phone slept gets reconciled.
    useEffect(() => onConnectionState((up) => {
        setConnected(up);
        if (up) refresh();
    }), [refresh]);

    useEffect(
        () =>
            onFleetEvent((event) => {
                switch (event.type) {
                    case "fleet.status":
                        setFleet({ machines: event.machines, diffusionOnline: event.diffusionOnline });
                        break;
                    case "session.created":
                    case "session.updated":
                        setSessions((prev) => {
                            const next = prev.filter((s) => s.id !== event.session.id);
                            next.push(event.session);
                            next.sort((a, b) => b.updatedAt - a.updatedAt);
                            return next;
                        });
                        break;
                    case "session.deleted":
                        setSessions((prev) => prev.filter((s) => s.id !== event.sessionId));
                        break;
                    case "diffusion.job":
                        setJobs((prev) => {
                            const next = prev.filter((j) => j.id !== event.job.id);
                            next.unshift(event.job);
                            next.sort((a, b) => b.createdAt - a.createdAt);
                            return next;
                        });
                        break;
                    default:
                        break;
                }
            }),
        [],
    );

    const currentSession = useMemo(
        () =>
            route.tab === "chat" && route.sessionId
                ? sessions.find((s) => s.id === route.sessionId)
                : undefined,
        [route, sessions],
    );

    return (
        <div className="app">
            {!connected && (
                <div className="banner" onClick={reconnectEvents}>
                    Reconnecting to orchestrator… (tap to retry)
                </div>
            )}
            <main className="content">
                {route.tab === "chat" && (
                    <ChatView
                        fleet={fleet}
                        sessions={sessions}
                        session={currentSession}
                        onOpenSettings={() => setShowSettings(true)}
                    />
                )}
                {route.tab === "images" && <ImagesView fleet={fleet} jobs={jobs} />}
                {route.tab === "machines" && <MachinesView fleet={fleet} onRefresh={refresh} />}
            </main>
            <nav className="tabbar">
                <a href="#/chat" className={route.tab === "chat" ? "active" : ""}>
                    💬 Chat
                </a>
                <a href="#/images" className={route.tab === "images" ? "active" : ""}>
                    🎨 Images
                </a>
                <a href="#/machines" className={route.tab === "machines" ? "active" : ""}>
                    🖥 Fleet
                </a>
            </nav>
            {showSettings && <SettingsSheet onClose={() => setShowSettings(false)} />}
        </div>
    );
}

function SettingsSheet({ onClose }: { onClose: () => void }) {
    const [token, setTokenState] = useState(getToken());
    return (
        <div className="sheet-backdrop" onClick={onClose}>
            <div className="sheet" onClick={(e) => e.stopPropagation()}>
                <h2>Settings</h2>
                <label className="field">
                    <span>Fleet token (optional)</span>
                    <input
                        type="password"
                        value={token}
                        placeholder="leave empty if the fleet has no token"
                        onChange={(e) => setTokenState(e.target.value)}
                    />
                </label>
                <p className="hint">
                    Only needed when the orchestrator is started with a shared token.
                    Tailscale device identity is the primary trust boundary.
                </p>
                <button
                    className="primary"
                    onClick={() => {
                        setToken(token.trim());
                        reconnectEvents();
                        onClose();
                    }}
                >
                    Save
                </button>
            </div>
        </div>
    );
}
