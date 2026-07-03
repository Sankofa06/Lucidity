// Fleet/orchestrator/src/index.ts
//
// What: Orchestrator entrypoint (runs on the always-on Mac Mini).
// Does: Loads fleet config, opens SQLite, wires the fleet monitor, session
//       service, diffusion gateway, and SSE hub together, mounts /api, and
//       serves the built PWA so the phone has a single origin to talk to.
// Touches: every orchestrator module; pwa/dist static files.
// Touched by: launchd/Task Scheduler units from Fleet/deploy.

import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import express from "express";
import { SseHub, type FleetEvent } from "@lucidity/shared";
import { buildApi } from "./api.js";
import { loadConfig } from "./config.js";
import { FleetDb } from "./db.js";
import { DiffusionGateway } from "./diffusion.js";
import { FleetMonitor } from "./fleet.js";
import { SessionService } from "./sessions.js";

const config = loadConfig();
const db = new FleetDb(config.dataDir);
const hub = new SseHub<FleetEvent>();

// Fleet monitor forwards every opencode event into the session mirror.
// (sessions is declared below; the arrow defers the dereference until events flow.)
const fleet = new FleetMonitor(config, hub, (machineId, event) =>
    sessions.handleOpencodeEvent(machineId, event),
);
const sessions = new SessionService(db, fleet, hub);
const diffusion = new DiffusionGateway(config, hub);

fleet.start();
diffusion.start();
setInterval(() => hub.heartbeat(), 15_000);

const app = express();
app.use("/api", buildApi({ config, fleet, sessions, diffusion, hub }));

// Serve the PWA build when present (single origin for the phone).
const here = path.dirname(fileURLToPath(import.meta.url));
const pwaDist = process.env.PWA_DIST ?? path.resolve(here, "..", "..", "pwa", "dist");
if (fs.existsSync(pwaDist)) {
    app.use(express.static(pwaDist));
    // SPA fallback: any non-API GET renders the app shell.
    app.get(/^\/(?!api\/).*/, (_req, res) => {
        res.sendFile(path.join(pwaDist, "index.html"));
    });
} else {
    app.get("/", (_req, res) => {
        res.type("text/plain").send(
            "lucidity-orchestrator is running, but the PWA build was not found.\n" +
                `Expected at: ${pwaDist}\nRun: npm run build -w pwa`,
        );
    });
}

// 0.0.0.0 is intentional: the tailnet is the trust boundary; nothing here is
// exposed publicly (no port forwarding, no funnel).
const server = app.listen(config.port, "0.0.0.0", () => {
    console.log(
        `lucidity-orchestrator listening on :${config.port} — machines: ${config.machines
            .map((m) => m.id)
            .join(", ")}`,
    );
});

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
function shutdown(): void {
    fleet.stop();
    diffusion.stop();
    db.close();
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 3_000).unref();
}
