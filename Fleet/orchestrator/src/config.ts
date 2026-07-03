// Fleet/orchestrator/src/config.ts
//
// What: Fleet configuration loading for the orchestrator.
// Does: Reads a JSON config file (path from FLEET_CONFIG env, with sensible
//       fallbacks), validates it with zod, and expands ~ in dataDir.
// Touches: filesystem (config file), process.env.
// Touched by: index.ts at startup; the config object flows into every service.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import type { MachineConfig } from "@lucidity/shared";

const machineSchema = z.object({
    id: z.string().regex(/^[\w-]+$/),
    name: z.string(),
    host: z.string(),
    platform: z.enum(["macos", "windows"]),
    opencodePort: z.number().int().default(4096),
    lmstudioPort: z.number().int().optional(),
});

const configSchema = z.object({
    /** Orchestrator HTTP port (PWA + API). */
    port: z.number().int().default(8780),
    /** SQLite + misc state directory. */
    dataDir: z.string().default("~/.lucidity-fleet/orchestrator"),
    /** Optional shared token required from clients (and sent to diffusion). */
    token: z.string().optional(),
    /** The MCP diffusion service (its REST side). */
    diffusion: z.object({ url: z.string().url() }),
    machines: z.array(machineSchema).min(1),
});

export interface FleetConfig {
    port: number;
    dataDir: string;
    token?: string;
    diffusionUrl: string;
    machines: MachineConfig[];
}

/**
 * Resolution order: $FLEET_CONFIG, then LocalDev/fleet.local.json (repo-ignored,
 * real tailnet hosts), then Fleet/config/fleet.example.json (fake hosts, so a
 * fresh checkout at least boots).
 */
export function configCandidates(): string[] {
    const here = path.dirname(fileURLToPath(import.meta.url));
    const repoRoot = path.resolve(here, "..", "..", "..");
    return [
        process.env.FLEET_CONFIG ?? "",
        path.join(repoRoot, "LocalDev", "fleet.local.json"),
        path.join(repoRoot, "Fleet", "config", "fleet.example.json"),
    ].filter(Boolean);
}

export function loadConfig(explicitPath?: string): FleetConfig {
    const candidates = explicitPath ? [explicitPath] : configCandidates();
    const file = candidates.find((p) => fs.existsSync(p));
    if (!file) {
        throw new Error(
            `No fleet config found. Set FLEET_CONFIG or create one of: ${candidates.join(", ")}`,
        );
    }
    const parsed = configSchema.parse(JSON.parse(fs.readFileSync(file, "utf8")));
    const dataDir = parsed.dataDir.startsWith("~")
        ? path.join(os.homedir(), parsed.dataDir.slice(1))
        : parsed.dataDir;
    console.log(`fleet config loaded from ${file}`);
    return {
        port: parsed.port,
        dataDir,
        token: parsed.token || process.env.FLEET_TOKEN || undefined,
        diffusionUrl: parsed.diffusion.url.replace(/\/+$/, ""),
        machines: parsed.machines,
    };
}
