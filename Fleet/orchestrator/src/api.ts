// Fleet/orchestrator/src/api.ts
//
// What: The orchestrator's HTTP API — everything the PWA talks to.
// Does: Fleet status, session CRUD + chat, continue-elsewhere, the global SSE
//       event stream (with Last-Event-ID replay), and diffusion proxying.
// Touches: SessionService, FleetMonitor, DiffusionGateway, SseHub.
// Touched by: index.ts (mounts under /api); the PWA is the sole client.

import { Router, json, type NextFunction, type Request, type Response } from "express";
import type { FleetEvent, HealthResponse, SseHub } from "@lucidity/shared";
import type { FleetConfig } from "./config.js";
import type { DiffusionGateway } from "./diffusion.js";
import type { FleetMonitor } from "./fleet.js";
import { MachineOfflineError, NotFoundError, type SessionService } from "./sessions.js";

const VERSION = "0.1.0";
const startedAt = Date.now();

export function buildApi(deps: {
    config: FleetConfig;
    fleet: FleetMonitor;
    sessions: SessionService;
    diffusion: DiffusionGateway;
    hub: SseHub<FleetEvent>;
}): Router {
    const { config, fleet, sessions, diffusion, hub } = deps;
    const router = Router();
    router.use(json({ limit: "2mb" }));

    // Optional shared-token gate (Tailscale is the primary boundary).
    // EventSource can't set headers, so GETs may pass the token as ?token=.
    router.use((req, res, next) => {
        if (!config.token) return next();
        const supplied =
            req.header("x-fleet-token") ?? (req.query.token as string | undefined);
        if (supplied === config.token) return next();
        res.status(401).json({ error: "missing or invalid fleet token" });
    });

    // ---- health + fleet -------------------------------------------------------
    router.get("/health", (_req, res) => {
        const body: HealthResponse = {
            ok: true,
            service: "lucidity-orchestrator",
            version: VERSION,
            uptimeSeconds: Math.round((Date.now() - startedAt) / 1000),
        };
        res.json(body);
    });

    router.get("/fleet", (_req, res) => {
        res.json(fleet.snapshot());
    });

    router.post(
        "/fleet/refresh",
        handle(async (_req, res) => {
            await fleet.pollOnce();
            res.json(fleet.snapshot());
        }),
    );

    router.post(
        "/machines/:id/adopt-sessions",
        handle(async (req, res) => {
            const adopted = await sessions.adoptFromMachine(param(req, "id"));
            res.json({ adopted });
        }),
    );

    // ---- events (PWA lifeline) --------------------------------------------------
    router.get("/events", (req, res) => {
        hub.attach(res, req.header("last-event-id"));
        // Push current state immediately so a reconnecting phone repaints fast.
        res.write(
            `data: ${JSON.stringify({ type: "fleet.status", ...fleet.snapshot() })}\n\n`,
        );
    });

    // ---- sessions ----------------------------------------------------------------
    router.get("/sessions", (req, res) => {
        res.json(sessions.list(req.query.archived === "1"));
    });

    router.post(
        "/sessions",
        handle(async (req, res) => {
            const { machineId, title, directory } = req.body ?? {};
            if (typeof machineId !== "string") {
                return res.status(400).json({ error: "machineId is required" });
            }
            res.status(201).json(await sessions.create({ machineId, title, directory }));
        }),
    );

    router.get(
        "/sessions/:id",
        handle(async (req, res) => {
            const record = sessions.get(param(req, "id"));
            if (!record) return res.status(404).json({ error: "unknown session" });
            // Best-effort resync from the pinned machine; offline just serves the mirror.
            await sessions.syncMessages(record.id).catch(() => undefined);
            res.json({ session: sessions.get(record.id), messages: sessions.messages(record.id) });
        }),
    );

    router.patch(
        "/sessions/:id",
        handle(async (req, res) => {
            const { title, archived } = req.body ?? {};
            res.json(sessions.update(param(req, "id"), { title, archived }));
        }),
    );

    router.delete(
        "/sessions/:id",
        handle(async (req, res) => {
            await sessions.remove(param(req, "id"));
            res.status(204).end();
        }),
    );

    router.post(
        "/sessions/:id/messages",
        handle(async (req, res) => {
            const { text, providerID, modelID, agent } = req.body ?? {};
            if (typeof text !== "string" || text.trim() === "") {
                return res.status(400).json({ error: "text is required" });
            }
            await sessions.sendMessage(param(req, "id"), { text, providerID, modelID, agent });
            res.status(202).json({ accepted: true });
        }),
    );

    router.post(
        "/sessions/:id/abort",
        handle(async (req, res) => {
            await sessions.abort(param(req, "id"));
            res.json({ aborted: true });
        }),
    );

    router.post(
        "/sessions/:id/continue",
        handle(async (req, res) => {
            const { machineId } = req.body ?? {};
            if (typeof machineId !== "string") {
                return res.status(400).json({ error: "machineId is required" });
            }
            res.status(201).json(await sessions.continueOn(param(req, "id"), machineId));
        }),
    );

    // ---- diffusion (proxied so the phone only ever talks to the orchestrator) ----
    router.get(
        "/diffusion/jobs",
        handle(async (req, res) => {
            const limit = Number.parseInt(String(req.query.limit ?? "50"), 10) || 50;
            res.json(await diffusion.listJobs(limit));
        }),
    );

    router.post(
        "/diffusion/jobs",
        handle(async (req, res) => {
            const { prompt } = req.body ?? {};
            if (typeof prompt !== "string" || prompt.trim() === "") {
                return res.status(400).json({ error: "prompt is required" });
            }
            res.status(201).json(await diffusion.createJob(req.body));
        }),
    );

    router.get(
        "/diffusion/jobs/:id",
        handle(async (req, res) => {
            res.json(await diffusion.getJob(param(req, "id")));
        }),
    );

    router.post(
        "/diffusion/jobs/:id/cancel",
        handle(async (req, res) => {
            res.json(await diffusion.cancelJob(param(req, "id")));
        }),
    );

    router.get(
        "/diffusion/workflows",
        handle(async (_req, res) => {
            res.json(await diffusion.listWorkflows());
        }),
    );

    router.get(
        "/diffusion/images/:filename",
        handle(async (req, res) => {
            const upstream = await diffusion.fetchImage(param(req, "filename"));
            if (!upstream.ok || !upstream.body) {
                return res.status(upstream.status).json({ error: "image unavailable" });
            }
            res.setHeader(
                "content-type",
                upstream.headers.get("content-type") ?? "image/png",
            );
            res.setHeader("cache-control", "private, max-age=31536000, immutable");
            const bytes = Buffer.from(await upstream.arrayBuffer());
            res.end(bytes);
        }),
    );

    // ---- error mapping -------------------------------------------------------------
    router.use(
        (err: unknown, _req: Request, res: Response, _next: NextFunction) => {
            if (err instanceof NotFoundError) {
                return res.status(404).json({ error: err.message });
            }
            if (err instanceof MachineOfflineError) {
                return res.status(503).json({ error: err.message });
            }
            console.error("api error:", err);
            res.status(500).json({
                error: err instanceof Error ? err.message : "internal error",
            });
        },
    );

    return router;
}

/** Route param accessor; express guarantees presence for matched routes. */
function param(req: Request, name: string): string {
    return req.params[name] ?? "";
}

/** Wrap an async handler so rejections reach the error middleware. */
function handle(
    fn: (req: Request, res: Response) => Promise<unknown>,
): (req: Request, res: Response, next: NextFunction) => void {
    return (req, res, next) => {
        fn(req, res).catch(next);
    };
}
