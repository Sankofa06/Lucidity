// Fleet/mcp-diffusion/src/config.ts
//
// What: Environment-driven configuration for the MCP diffusion server.
// Does: Reads env vars (with tailnet-friendly defaults) into a typed object.
// Touches: process.env, node:path, node:os.
// Touched by: index.ts at startup; passed into ComfyClient/JobManager/MCP tools.

import os from "node:os";
import path from "node:path";

export interface DiffusionConfig {
    /** Port this service listens on, bound to 0.0.0.0 inside the tailnet. */
    port: number;
    /** Base URL of the ComfyUI HTTP API (usually the RTX 4070 box). */
    comfyUrl: string;
    /** Where job metadata and finished images are persisted. */
    dataDir: string;
    /** Directory holding custom ComfyUI API-format workflow templates. */
    workflowsDir: string;
    /** Default checkpoint file used by the builtin txt2img graph. */
    defaultCheckpoint: string;
    /** Optional shared token; when set, /api and /mcp require it. */
    token?: string;
    /** How long generate_image (MCP tool) waits before giving up, ms. */
    generateTimeoutMs: number;
    /** Embed finished images into MCP tool results when small enough. */
    includeImageInResult: boolean;
    /** Max raw image bytes to embed in an MCP result. */
    maxEmbeddedImageBytes: number;
}

/** Read config from the environment. Every value has a sane single-user default. */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): DiffusionConfig {
    const dataDir =
        env.DIFFUSION_DATA_DIR ?? path.join(os.homedir(), ".lucidity-fleet", "diffusion");
    return {
        port: intFrom(env.DIFFUSION_PORT, 8790),
        comfyUrl: (env.COMFY_URL ?? "http://127.0.0.1:8188").replace(/\/+$/, ""),
        dataDir,
        workflowsDir: env.DIFFUSION_WORKFLOWS_DIR ?? path.join(dataDir, "workflows"),
        defaultCheckpoint: env.COMFY_CHECKPOINT ?? "sd_xl_base_1.0.safetensors",
        token: env.FLEET_TOKEN || undefined,
        generateTimeoutMs: intFrom(env.DIFFUSION_GENERATE_TIMEOUT_MS, 600_000),
        includeImageInResult: (env.DIFFUSION_EMBED_IMAGES ?? "true") !== "false",
        maxEmbeddedImageBytes: intFrom(env.DIFFUSION_MAX_EMBED_BYTES, 3_000_000),
    };
}

function intFrom(raw: string | undefined, fallback: number): number {
    const parsed = raw ? Number.parseInt(raw, 10) : Number.NaN;
    return Number.isFinite(parsed) ? parsed : fallback;
}
