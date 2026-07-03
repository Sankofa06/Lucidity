// Fleet/mcp-diffusion/src/mcp.ts
//
// What: MCP tool definitions wrapping the diffusion JobManager.
// Does: Builds a fresh McpServer (stateless transport pattern) exposing image
//       generation, job status, image retrieval, queue state, and workflow
//       listing to opencode agents on any fleet machine.
// Touches: JobManager, workflows.ts, filesystem (reading finished images).
// Touched by: index.ts, which instantiates one server per /mcp request.

import fs from "node:fs";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { DiffusionJob } from "@lucidity/shared";
import type { DiffusionConfig } from "./config.js";
import { isTerminal, JobManager } from "./jobs.js";
import { listWorkflows } from "./workflows.js";

const generateInput = {
    prompt: z.string().describe("Positive prompt describing the image to generate"),
    negative_prompt: z.string().optional().describe("Things to avoid in the image"),
    width: z.number().int().min(64).max(4096).optional().describe("Pixels, default 1024"),
    height: z.number().int().min(64).max(4096).optional().describe("Pixels, default 1024"),
    steps: z.number().int().min(1).max(150).optional().describe("Sampler steps, default 25"),
    cfg: z.number().min(0).max(30).optional().describe("CFG scale, default 6.5"),
    seed: z.number().int().optional().describe("Random when omitted"),
    checkpoint: z.string().optional().describe("Checkpoint filename; server default when omitted"),
    workflow: z
        .string()
        .optional()
        .describe("Named custom workflow template (see list_workflows) instead of the builtin txt2img graph"),
    wait: z
        .boolean()
        .optional()
        .describe("Default true: block until the image is done and return it. false: return the job id immediately; poll with get_job_status."),
};

export function buildMcpServer(jobs: JobManager, config: DiffusionConfig): McpServer {
    const server = new McpServer({ name: "lucidity-diffusion", version: "0.1.0" });

    server.registerTool(
        "generate_image",
        {
            title: "Generate image with ComfyUI",
            description:
                "Generate an image on the fleet's diffusion machine (ComfyUI). " +
                "By default this waits for completion and returns the finished image plus its saved location. " +
                "Use it mid-session for reference textures, UI mockups, concept art, and similar assets.",
            inputSchema: generateInput,
        },
        async (args) => {
            const job = await jobs.create(
                {
                    prompt: args.prompt,
                    negativePrompt: args.negative_prompt,
                    width: args.width,
                    height: args.height,
                    steps: args.steps,
                    cfg: args.cfg,
                    seed: args.seed,
                    checkpoint: args.checkpoint,
                    workflow: args.workflow,
                },
                "mcp",
            );
            if (job.status === "failed") {
                return errorResult(`Submission failed: ${job.error}`);
            }
            if (args.wait === false) {
                return textResult(
                    `Job ${job.id} queued (ComfyUI prompt ${job.comfyPromptId}). ` +
                        `Poll with get_job_status.`,
                );
            }
            const done = await jobs
                .waitForCompletion(job.id, config.generateTimeoutMs)
                .catch((err: Error) => err);
            if (done instanceof Error) return errorResult(done.message);
            return jobResult(done, jobs, config, { embedImages: true });
        },
    );

    server.registerTool(
        "get_job_status",
        {
            title: "Get diffusion job status",
            description:
                "Status, progress, and queue position of a diffusion job started with generate_image.",
            inputSchema: { job_id: z.string() },
        },
        async ({ job_id }) => {
            const job = jobs.get(job_id);
            if (!job) return errorResult(`Unknown job ${job_id}`);
            return jobResult(job, jobs, config, { embedImages: false });
        },
    );

    server.registerTool(
        "get_image",
        {
            title: "Fetch a generated image",
            description: "Return a finished job's image content by job id.",
            inputSchema: {
                job_id: z.string(),
                index: z.number().int().min(0).optional().describe("Image index for batch jobs, default 0"),
            },
        },
        async ({ job_id, index }) => {
            const job = jobs.get(job_id);
            if (!job) return errorResult(`Unknown job ${job_id}`);
            const image = job.images[index ?? 0];
            if (!image) return errorResult(`Job ${job_id} has no image at index ${index ?? 0}`);
            const filePath = jobs.imagePath(image.filename);
            if (!filePath) return errorResult(`Image file missing: ${image.filename}`);
            const bytes = fs.readFileSync(filePath);
            if (bytes.length > config.maxEmbeddedImageBytes) {
                return textResult(
                    `Image too large to embed (${bytes.length} bytes). Saved at ${filePath}; ` +
                        `also served at /api/images/${image.filename}.`,
                );
            }
            return {
                content: [
                    imageContent(bytes, image.filename),
                    { type: "text" as const, text: `Saved at ${filePath}` },
                ],
            };
        },
    );

    server.registerTool(
        "list_jobs",
        {
            title: "List diffusion jobs",
            description: "Recent diffusion jobs with status and parameters.",
            inputSchema: { limit: z.number().int().min(1).max(100).optional() },
        },
        async ({ limit }) => textResult(JSON.stringify(jobs.list(limit ?? 20), null, 2)),
    );

    server.registerTool(
        "list_workflows",
        {
            title: "List custom workflows",
            description:
                "Named ComfyUI workflow templates usable via generate_image's `workflow` argument.",
            inputSchema: {},
        },
        async () => {
            const names = listWorkflows(config.workflowsDir);
            return textResult(
                names.length
                    ? names.join("\n")
                    : "No custom workflows installed; the builtin txt2img graph is used.",
            );
        },
    );

    server.registerTool(
        "get_queue_state",
        {
            title: "Get diffusion queue state",
            description: "Whether ComfyUI is reachable and what is running/pending.",
            inputSchema: {},
        },
        async () => {
            const online = await jobs.comfyOnline();
            if (!online) return textResult("ComfyUI is OFFLINE (unreachable).");
            const queue = await jobs.comfy.queue();
            return textResult(
                `ComfyUI online. Running: ${queue.running.length}, pending: ${queue.pending.length}.`,
            );
        },
    );

    return server;
}

// ---- result helpers ---------------------------------------------------------

type ToolResult = {
    content: Array<
        | { type: "text"; text: string }
        | { type: "image"; data: string; mimeType: string }
    >;
    isError?: boolean;
};

function textResult(text: string): ToolResult {
    return { content: [{ type: "text", text }] };
}

function errorResult(text: string): ToolResult {
    return { content: [{ type: "text", text }], isError: true };
}

function imageContent(bytes: Buffer, filename: string) {
    const mimeType = filename.endsWith(".webp")
        ? "image/webp"
        : filename.endsWith(".jpg") || filename.endsWith(".jpeg")
          ? "image/jpeg"
          : "image/png";
    return { type: "image" as const, data: bytes.toString("base64"), mimeType };
}

function jobResult(
    job: DiffusionJob,
    jobs: JobManager,
    config: DiffusionConfig,
    opts: { embedImages: boolean },
): ToolResult {
    const lines = [
        `Job ${job.id}: ${job.status}`,
        job.progress ? `Progress: ${job.progress.value}/${job.progress.max}` : undefined,
        job.queuePosition !== undefined ? `Queue position: ${job.queuePosition}` : undefined,
        job.error ? `Error: ${job.error}` : undefined,
        `Seed: ${job.params.seed}`,
        ...job.images.map((img) => {
            const p = jobs.imagePath(img.filename);
            return `Image: ${img.filename}${p ? ` (saved at ${p})` : ""} — served at /api/images/${img.filename}`;
        }),
    ].filter((l): l is string => Boolean(l));
    const result: ToolResult = { content: [{ type: "text", text: lines.join("\n") }] };
    if (job.status === "failed") result.isError = true;
    if (opts.embedImages && config.includeImageInResult && isTerminal(job)) {
        for (const img of job.images) {
            const filePath = jobs.imagePath(img.filename);
            if (!filePath) continue;
            const bytes = fs.readFileSync(filePath);
            if (bytes.length <= config.maxEmbeddedImageBytes) {
                result.content.push(imageContent(bytes, img.filename));
            }
        }
    }
    return result;
}
