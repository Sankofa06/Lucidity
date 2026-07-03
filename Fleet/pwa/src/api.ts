// Fleet/pwa/src/api.ts
//
// What: HTTP client for the orchestrator API.
// Does: Thin typed fetch wrappers; attaches the optional fleet token from
//       localStorage; the PWA never talks to opencode or ComfyUI directly.
// Touches: /api/* on the same origin (the orchestrator serves this app).
// Touched by: App.tsx and all views.

import type {
    DiffusionJob,
    DiffusionParams,
    FleetSnapshot,
    MessageRecord,
    SessionRecord,
} from "./types";

const TOKEN_KEY = "lucidity.fleetToken";

export function getToken(): string {
    return localStorage.getItem(TOKEN_KEY) ?? "";
}

export function setToken(token: string): void {
    if (token) localStorage.setItem(TOKEN_KEY, token);
    else localStorage.removeItem(TOKEN_KEY);
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
    const headers: Record<string, string> = {};
    const token = getToken();
    if (token) headers["x-fleet-token"] = token;
    if (body !== undefined) headers["content-type"] = "application/json";
    const res = await fetch(`/api${path}`, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (res.status === 204) return undefined as T;
    const json = (await res.json().catch(() => ({}))) as T & { error?: string };
    if (!res.ok) throw new Error(json.error ?? `Request failed (${res.status})`);
    return json;
}

export const api = {
    fleet: () => request<FleetSnapshot>("GET", "/fleet"),
    refreshFleet: () => request<FleetSnapshot>("POST", "/fleet/refresh"),
    adoptSessions: (machineId: string) =>
        request<{ adopted: number }>("POST", `/machines/${machineId}/adopt-sessions`),

    sessions: () => request<SessionRecord[]>("GET", "/sessions"),
    createSession: (input: { machineId: string; title?: string; directory?: string }) =>
        request<SessionRecord>("POST", "/sessions", input),
    session: (id: string) =>
        request<{ session: SessionRecord; messages: MessageRecord[] }>(
            "GET",
            `/sessions/${id}`,
        ),
    updateSession: (id: string, fields: { title?: string; archived?: boolean }) =>
        request<SessionRecord>("PATCH", `/sessions/${id}`, fields),
    deleteSession: (id: string) => request<void>("DELETE", `/sessions/${id}`),
    sendMessage: (
        id: string,
        input: { text: string; providerID?: string; modelID?: string },
    ) => request<{ accepted: boolean }>("POST", `/sessions/${id}/messages`, input),
    abortSession: (id: string) => request<{ aborted: boolean }>("POST", `/sessions/${id}/abort`),
    continueSession: (id: string, machineId: string) =>
        request<SessionRecord>("POST", `/sessions/${id}/continue`, { machineId }),

    diffusionJobs: () => request<DiffusionJob[]>("GET", "/diffusion/jobs?limit=100"),
    createDiffusionJob: (params: DiffusionParams) =>
        request<DiffusionJob>("POST", "/diffusion/jobs", params),
    cancelDiffusionJob: (id: string) =>
        request<DiffusionJob>("POST", `/diffusion/jobs/${id}/cancel`),
    diffusionWorkflows: () => request<string[]>("GET", "/diffusion/workflows"),
};

/** Image URL via the orchestrator proxy (token as query — <img> can't set headers). */
export function imageUrl(filename: string): string {
    const token = getToken();
    const suffix = token ? `?token=${encodeURIComponent(token)}` : "";
    return `/api/diffusion/images/${encodeURIComponent(filename)}${suffix}`;
}
