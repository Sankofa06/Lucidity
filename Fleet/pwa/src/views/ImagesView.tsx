// Fleet/pwa/src/views/ImagesView.tsx
//
// What: The images tab — standalone diffusion from the phone.
// Does: Generation form (prompt/size/steps/workflow), live job cards driven by
//       SSE (queue position, sampler progress bar), and a gallery of results
//       served through the orchestrator proxy.
// Touches: api.ts (jobs come in via App's SSE subscription as props).
// Touched by: App.tsx.

import { useEffect, useState } from "react";
import { api, imageUrl } from "../api";
import type { DiffusionJob, FleetSnapshot } from "../types";

export function ImagesView(props: { fleet: FleetSnapshot; jobs: DiffusionJob[] }) {
    const [prompt, setPrompt] = useState("");
    const [negative, setNegative] = useState("");
    const [size, setSize] = useState("1024x1024");
    const [steps, setSteps] = useState(25);
    const [workflow, setWorkflow] = useState("");
    const [workflows, setWorkflows] = useState<string[]>([]);
    const [error, setError] = useState("");
    const [submitting, setSubmitting] = useState(false);

    useEffect(() => {
        api.diffusionWorkflows().then(setWorkflows).catch(() => {});
    }, []);

    const submit = async () => {
        if (!prompt.trim()) return;
        setSubmitting(true);
        setError("");
        const [w, h] = size.split("x").map((n) => Number.parseInt(n, 10));
        try {
            await api.createDiffusionJob({
                prompt: prompt.trim(),
                negativePrompt: negative.trim() || undefined,
                width: w,
                height: h,
                steps,
                workflow: workflow || undefined,
            });
        } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
        } finally {
            setSubmitting(false);
        }
    };

    return (
        <div className="page">
            <header className="pagehead">
                <h1>Images</h1>
                <span className={props.fleet.diffusionOnline ? "pill on" : "pill off"}>
                    {props.fleet.diffusionOnline ? "ComfyUI online" : "ComfyUI offline"}
                </span>
            </header>

            <div className="genform">
                <textarea
                    value={prompt}
                    rows={3}
                    placeholder="Prompt — e.g. brushed titanium heat shield texture, macro photo"
                    onChange={(e) => setPrompt(e.target.value)}
                />
                <input
                    value={negative}
                    placeholder="Negative prompt (optional)"
                    onChange={(e) => setNegative(e.target.value)}
                />
                <div className="genform-row">
                    <select value={size} onChange={(e) => setSize(e.target.value)}>
                        <option>1024x1024</option>
                        <option>1152x896</option>
                        <option>896x1152</option>
                        <option>1344x768</option>
                        <option>768x1344</option>
                        <option>512x512</option>
                    </select>
                    <label className="steps">
                        {steps} steps
                        <input
                            type="range"
                            min={5}
                            max={60}
                            value={steps}
                            onChange={(e) => setSteps(Number(e.target.value))}
                        />
                    </label>
                </div>
                {workflows.length > 0 && (
                    <select value={workflow} onChange={(e) => setWorkflow(e.target.value)}>
                        <option value="">builtin txt2img</option>
                        {workflows.map((w) => (
                            <option key={w} value={w}>
                                workflow: {w}
                            </option>
                        ))}
                    </select>
                )}
                {error && <p className="error">{error}</p>}
                <button
                    className="primary"
                    disabled={!props.fleet.diffusionOnline || submitting || !prompt.trim()}
                    onClick={submit}
                >
                    Generate
                </button>
            </div>

            <div className="jobs">
                {props.jobs.map((job) => (
                    <JobCard key={job.id} job={job} />
                ))}
            </div>
        </div>
    );
}

function JobCard({ job }: { job: DiffusionJob }) {
    const pct =
        job.progress && job.progress.max > 0
            ? Math.round((job.progress.value / job.progress.max) * 100)
            : undefined;
    return (
        <div className={`jobcard ${job.status}`}>
            <div className="jobcard-head">
                <span className={`pill ${job.status}`}>{job.status}</span>
                {job.queuePosition !== undefined && job.status === "queued" && (
                    <span className="hint">#{job.queuePosition + 1} in queue</span>
                )}
                {job.source === "mcp" && <span className="hint">from agent</span>}
                {(job.status === "queued" || job.status === "running") && (
                    <button onClick={() => api.cancelDiffusionJob(job.id).catch(() => {})}>
                        Cancel
                    </button>
                )}
            </div>
            <div className="jobcard-prompt">{job.params.prompt}</div>
            {pct !== undefined && job.status === "running" && (
                <div className="progress">
                    <div className="progress-fill" style={{ width: `${pct}%` }} />
                </div>
            )}
            {job.error && <p className="error">{job.error}</p>}
            {job.images.length > 0 && (
                <div className="jobcard-images">
                    {job.images.map((img) => (
                        <a
                            key={img.filename}
                            href={imageUrl(img.filename)}
                            target="_blank"
                            rel="noreferrer"
                        >
                            <img src={imageUrl(img.filename)} alt={job.params.prompt} loading="lazy" />
                        </a>
                    ))}
                </div>
            )}
        </div>
    );
}
