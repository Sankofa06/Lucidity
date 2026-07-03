// Fleet/mcp-diffusion/test/workflows.test.ts
//
// What: Unit tests for workflow graph construction and template substitution.
// Does: Verifies parameter defaulting/clamping, the builtin graph's wiring,
//       and %%TOKEN%% substitution (including numeric type preservation).
// Touches: workflows.ts, a temp workflows dir.
// Touched by: vitest.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterAll, describe, expect, it } from "vitest";
import {
    buildDefaultWorkflow,
    listWorkflows,
    loadWorkflow,
    resolveParams,
} from "../src/workflows.js";

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "lucidity-workflows-"));
afterAll(() => fs.rmSync(tmp, { recursive: true, force: true }));

describe("resolveParams", () => {
    it("applies defaults and draws a random seed", () => {
        const p = resolveParams({ prompt: "a cat" }, "model.safetensors");
        expect(p.width).toBe(1024);
        expect(p.height).toBe(1024);
        expect(p.steps).toBe(25);
        expect(p.checkpoint).toBe("model.safetensors");
        expect(p.seed).toBeGreaterThanOrEqual(0);
        expect(p.batchSize).toBe(1);
    });

    it("clamps out-of-range values", () => {
        const p = resolveParams(
            { prompt: "x", width: 999999, steps: 0, cfg: 99 },
            "m.safetensors",
        );
        expect(p.width).toBe(4096);
        expect(p.steps).toBe(1);
        expect(p.cfg).toBe(30);
    });

    it("keeps an explicit seed", () => {
        expect(resolveParams({ prompt: "x", seed: 42 }, "m").seed).toBe(42);
    });
});

describe("buildDefaultWorkflow", () => {
    it("wires sampler inputs to the right nodes", () => {
        const p = resolveParams({ prompt: "hello", negativePrompt: "bad" }, "ckpt.safetensors");
        const graph = buildDefaultWorkflow(p);
        expect(graph.sampler!.inputs.model).toEqual(["checkpoint", 0]);
        expect(graph.sampler!.inputs.positive).toEqual(["positive", 0]);
        expect(graph.positive!.inputs.text).toBe("hello");
        expect(graph.negative!.inputs.text).toBe("bad");
        expect(graph.latent!.inputs.width).toBe(1024);
        expect(graph.save!.class_type).toBe("SaveImage");
    });
});

describe("custom workflows", () => {
    it("lists and substitutes tokens with type preservation", () => {
        fs.writeFileSync(
            path.join(tmp, "flux-dev.json"),
            JSON.stringify({
                enc: {
                    class_type: "CLIPTextEncode",
                    inputs: { text: "photo of %%PROMPT%%, best quality" },
                },
                sampler: {
                    class_type: "KSampler",
                    inputs: { seed: "%%SEED%%", steps: "%%STEPS%%" },
                },
            }),
        );
        expect(listWorkflows(tmp)).toEqual(["flux-dev"]);
        const p = resolveParams({ prompt: "a fox", seed: 7, steps: 12 }, "m");
        const graph = loadWorkflow(tmp, "flux-dev", p);
        expect(graph.enc!.inputs.text).toBe("photo of a fox, best quality");
        // Exact-match tokens keep their numeric type for ComfyUI validation.
        expect(graph.sampler!.inputs.seed).toBe(7);
        expect(graph.sampler!.inputs.steps).toBe(12);
    });

    it("rejects traversal-style workflow names", () => {
        const p = resolveParams({ prompt: "x" }, "m");
        expect(() => loadWorkflow(tmp, "../evil", p)).toThrow(/Invalid workflow name/);
    });

    it("throws a clear error for missing workflows", () => {
        const p = resolveParams({ prompt: "x" }, "m");
        expect(() => loadWorkflow(tmp, "nope", p)).toThrow(/Workflow not found/);
    });
});
