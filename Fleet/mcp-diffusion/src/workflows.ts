// Fleet/mcp-diffusion/src/workflows.ts
//
// What: ComfyUI workflow graph construction.
// Does: Builds the builtin txt2img graph (checkpoint -> CLIP encode -> KSampler
//       -> VAE decode -> SaveImage) and loads/instantiates custom workflow
//       templates from disk with %%TOKEN%% substitution.
// Touches: node:fs (workflows dir only).
// Touched by: jobs.ts (graph per job) and mcp.ts / REST (list workflows).

import fs from "node:fs";
import path from "node:path";
import type { DiffusionParams } from "@lucidity/shared";

/** A ComfyUI "API format" graph: node id -> { class_type, inputs }. */
export type ComfyGraph = Record<
    string,
    { class_type: string; inputs: Record<string, unknown>; _meta?: { title?: string } }
>;

export interface ResolvedParams extends Required<
    Pick<DiffusionParams, "prompt" | "width" | "height" | "steps" | "cfg" | "seed" | "sampler" | "batchSize">
> {
    negativePrompt: string;
    checkpoint: string;
    workflow?: string;
}

/** Fill in defaults; a fresh random seed is drawn when none was given. */
export function resolveParams(params: DiffusionParams, defaultCheckpoint: string): ResolvedParams {
    return {
        prompt: params.prompt,
        negativePrompt: params.negativePrompt ?? "",
        width: clampInt(params.width ?? 1024, 64, 4096),
        height: clampInt(params.height ?? 1024, 64, 4096),
        steps: clampInt(params.steps ?? 25, 1, 150),
        cfg: clampNumber(params.cfg ?? 6.5, 0, 30),
        seed: params.seed ?? randomSeed(),
        sampler: params.sampler ?? "euler",
        checkpoint: params.checkpoint ?? defaultCheckpoint,
        batchSize: clampInt(params.batchSize ?? 1, 1, 8),
        workflow: params.workflow,
    };
}

/**
 * Builtin txt2img graph. Node ids are arbitrary strings; connections are
 * [nodeId, outputIndex] pairs, exactly what POST /prompt expects.
 */
export function buildDefaultWorkflow(p: ResolvedParams): ComfyGraph {
    return {
        checkpoint: {
            class_type: "CheckpointLoaderSimple",
            inputs: { ckpt_name: p.checkpoint },
        },
        positive: {
            class_type: "CLIPTextEncode",
            inputs: { text: p.prompt, clip: ["checkpoint", 1] },
        },
        negative: {
            class_type: "CLIPTextEncode",
            inputs: { text: p.negativePrompt, clip: ["checkpoint", 1] },
        },
        latent: {
            class_type: "EmptyLatentImage",
            inputs: { width: p.width, height: p.height, batch_size: p.batchSize },
        },
        sampler: {
            class_type: "KSampler",
            inputs: {
                model: ["checkpoint", 0],
                positive: ["positive", 0],
                negative: ["negative", 0],
                latent_image: ["latent", 0],
                seed: p.seed,
                steps: p.steps,
                cfg: p.cfg,
                sampler_name: p.sampler,
                scheduler: "normal",
                denoise: 1.0,
            },
        },
        decode: {
            class_type: "VAEDecode",
            inputs: { samples: ["sampler", 0], vae: ["checkpoint", 2] },
        },
        save: {
            class_type: "SaveImage",
            inputs: { images: ["decode", 0], filename_prefix: "lucidity" },
        },
    };
}

/** Names of custom workflow templates available on disk (without .json). */
export function listWorkflows(workflowsDir: string): string[] {
    if (!fs.existsSync(workflowsDir)) return [];
    return fs
        .readdirSync(workflowsDir)
        .filter((f) => f.endsWith(".json"))
        .map((f) => f.slice(0, -".json".length))
        .sort();
}

/**
 * Load a custom template and substitute %%TOKEN%% placeholders. A string value
 * that is exactly one numeric token becomes a number, so templates can feed
 * seeds/steps into numeric node inputs.
 */
export function loadWorkflow(workflowsDir: string, name: string, p: ResolvedParams): ComfyGraph {
    if (!/^[\w.-]+$/.test(name)) throw new Error(`Invalid workflow name: ${name}`);
    const file = path.join(workflowsDir, `${name}.json`);
    if (!fs.existsSync(file)) throw new Error(`Workflow not found: ${name}`);
    const raw = JSON.parse(fs.readFileSync(file, "utf8")) as ComfyGraph;
    const tokens: Record<string, string | number> = {
        "%%PROMPT%%": p.prompt,
        "%%NEGATIVE_PROMPT%%": p.negativePrompt,
        "%%SEED%%": p.seed,
        "%%STEPS%%": p.steps,
        "%%CFG%%": p.cfg,
        "%%WIDTH%%": p.width,
        "%%HEIGHT%%": p.height,
        "%%CHECKPOINT%%": p.checkpoint,
        "%%SAMPLER%%": p.sampler,
        "%%BATCH_SIZE%%": p.batchSize,
    };
    return substitute(raw, tokens) as ComfyGraph;
}

function substitute(value: unknown, tokens: Record<string, string | number>): unknown {
    if (typeof value === "string") {
        // Exact-match token: preserve the token's native type (numbers stay numbers).
        if (value in tokens) return tokens[value];
        let out = value;
        for (const [token, replacement] of Object.entries(tokens)) {
            out = out.split(token).join(String(replacement));
        }
        return out;
    }
    if (Array.isArray(value)) return value.map((v) => substitute(v, tokens));
    if (value && typeof value === "object") {
        return Object.fromEntries(
            Object.entries(value as Record<string, unknown>).map(([k, v]) => [
                k,
                substitute(v, tokens),
            ]),
        );
    }
    return value;
}

function randomSeed(): number {
    return Math.floor(Math.random() * 2 ** 48);
}

function clampInt(value: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, Math.round(value)));
}

function clampNumber(value: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, value));
}
