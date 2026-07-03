// Fleet/mcp-diffusion/src/index.ts
//
// What: MCP diffusion server entrypoint.
// Does: Hosts (a) the MCP Streamable HTTP endpoint at /mcp for opencode agents
//       and (b) a plain REST + SSE API under /api for the orchestrator:
//       job submission, job list/status, live job events, image files, health.
// Touches: express, JobManager (ComfyUI), SseHub, filesystem images dir.
// Touched by: opencode instances (MCP), the orchestrator (REST/SSE), deploy units.

import express from "express";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { SseHub, type DiffusionEvent, type HealthResponse } from "@lucidity/shared";
import { loadConfig } from "./config.js";
import { JobManager } from "./jobs.js";
import { buildMcpServer } from "./mcp.js";
import { listWorkflows } from "./workflows.js";

const VERSION = "0.1.0";
const startedAt = Date.now();

const config = loadConfig();
const jobs = new JobManager(config);
const hub = new SseHub<DiffusionEvent>();

jobs.on("job", (job) => hub.broadcast({ type: "job", job }));
jobs.start();
setInterval(() => hub.heartbeat(), 15_000);

const app = express();
app.use(express.json({ limit: "10mb" }));

// Optional shared-token check. Tailscale is the real boundary; this is
// defense-in-depth for multi-user tailnets. EventSource cannot set headers,
// so the token is also accepted as a query parameter on GET requests.
app.use((req, res, next) => {
    if (!config.token) return next();
    const supplied = req.header("x-fleet-token") ?? (req.query.token as string | undefined);
    if (supplied === config.token) return next();
    res.status(401).json({ error: "missing or invalid fleet token" });
});

// ---- MCP endpoint (stateless: fresh server + transport per request) ---------
app.post("/mcp", async (req, res) => {
    try {
        const server = buildMcpServer(jobs, config);
        const transport = new StreamableHTTPServerTransport({
            sessionIdGenerator: undefined,
            enableJsonResponse: true,
        });
        res.on("close", () => {
            void transport.close();
            void server.close();
        });
        await server.connect(transport);
        await transport.handleRequest(req, res, req.body);
    } catch (err) {
        if (!res.headersSent) {
            res.status(500).json({
                jsonrpc: "2.0",
                error: { code: -32603, message: String(err) },
                id: null,
            });
        }
    }
});
// Stateless mode has no server-initiated stream and no session to delete.
app.get("/mcp", (_req, res) => res.status(405).set("allow", "POST").end());
app.delete("/mcp", (_req, res) => res.status(405).set("allow", "POST").end());

// ---- REST API for the orchestrator ------------------------------------------
app.get("/api/health", async (_req, res) => {
    const comfyOnline = await jobs.comfyOnline();
    const body: HealthResponse & { comfyOnline: boolean } = {
        ok: true,
        service: "lucidity-mcp-diffusion",
        version: VERSION,
        uptimeSeconds: Math.round((Date.now() - startedAt) / 1000),
        comfyOnline,
    };
    res.json(body);
});

app.get("/api/jobs", (req, res) => {
    const limit = Number.parseInt(String(req.query.limit ?? "50"), 10) || 50;
    res.json(jobs.list(limit));
});

app.post("/api/jobs", async (req, res) => {
    const { prompt } = req.body ?? {};
    if (typeof prompt !== "string" || prompt.trim() === "") {
        return res.status(400).json({ error: "prompt is required" });
    }
    try {
        const job = await jobs.create(req.body, "orchestrator");
        res.status(job.status === "failed" ? 502 : 201).json(job);
    } catch (err) {
        res.status(400).json({ error: err instanceof Error ? err.message : String(err) });
    }
});

app.get("/api/jobs/:id", (req, res) => {
    const job = jobs.get(req.params.id);
    if (!job) return res.status(404).json({ error: "unknown job" });
    res.json(job);
});

app.post("/api/jobs/:id/cancel", async (req, res) => {
    const job = await jobs.cancel(req.params.id);
    if (!job) return res.status(404).json({ error: "unknown job" });
    res.json(job);
});

app.get("/api/workflows", (_req, res) => {
    res.json(listWorkflows(config.workflowsDir));
});

app.get("/api/images/:filename", (req, res) => {
    const filePath = jobs.imagePath(req.params.filename);
    if (!filePath) return res.status(404).json({ error: "unknown image" });
    res.sendFile(filePath);
});

// Live job updates for the orchestrator (and anything else on the tailnet).
app.get("/api/events", (req, res) => {
    hub.attach(res, req.header("last-event-id"));
});

// Bind to all interfaces: reachable tailnet-wide, and the tailnet is the
// trust boundary (no public exposure by design).
const server = app.listen(config.port, "0.0.0.0", () => {
    console.log(
        `lucidity-mcp-diffusion ${VERSION} listening on :${config.port}, ComfyUI at ${config.comfyUrl}`,
    );
});

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
function shutdown(): void {
    jobs.stop();
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 3_000).unref();
}
