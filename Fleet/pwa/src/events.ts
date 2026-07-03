// Fleet/pwa/src/events.ts
//
// What: Singleton SSE connection to the orchestrator's /api/events stream.
// Does: Manages one EventSource for the whole app, fans events out to
//       subscribers, and reports connection state. EventSource reconnects
//       automatically (sending Last-Event-ID, which the orchestrator replays),
//       which is exactly what a flapping Tailscale cellular link needs; we
//       additionally force a reconnect when the app returns to the foreground.
// Touches: /api/events (EventSource), document visibility.
// Touched by: App.tsx (lifecycle + fleet state) and ChatView (message stream).

import { getToken } from "./api";
import type { FleetEvent } from "./types";

type Listener = (event: FleetEvent) => void;
type StateListener = (connected: boolean) => void;

const listeners = new Set<Listener>();
const stateListeners = new Set<StateListener>();
let source: EventSource | undefined;
let connected = false;

function setConnected(value: boolean): void {
    if (connected === value) return;
    connected = value;
    for (const fn of stateListeners) fn(value);
}

export function connectEvents(): void {
    if (source) return;
    const token = getToken();
    const url = token ? `/api/events?token=${encodeURIComponent(token)}` : "/api/events";
    source = new EventSource(url);
    source.onopen = () => setConnected(true);
    source.onerror = () => setConnected(false); // EventSource retries on its own
    source.onmessage = (raw) => {
        try {
            const event = JSON.parse(raw.data) as FleetEvent;
            for (const fn of listeners) fn(event);
        } catch {
            /* ignore malformed frame */
        }
    };
}

/** Tear down + reopen; used on visibilitychange after long background gaps. */
export function reconnectEvents(): void {
    source?.close();
    source = undefined;
    setConnected(false);
    connectEvents();
}

export function onFleetEvent(fn: Listener): () => void {
    listeners.add(fn);
    return () => listeners.delete(fn);
}

export function onConnectionState(fn: StateListener): () => void {
    stateListeners.add(fn);
    fn(connected);
    return () => stateListeners.delete(fn);
}
