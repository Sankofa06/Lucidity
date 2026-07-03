# Mira

Mira is a chat-first AI studio for local machines, cloud models, media engines,
model sources, personas, teams, projects, and persistent sessions.

The first build focuses on the native app foundation: a polished chat workspace,
responsive inspector, Claude-style navigation rail, organized settings,
task-first route picker, Advisor chips, Developer Mode diagnostics, and endpoint
architecture for LM Studio, A1111/Forge, ComfyUI, Hugging Face, and CivitAI.
Users can add in-memory machine drafts, choose expected local endpoint ports,
refresh read-only probes, and hydrate routes into Chat, Inspector, Machines, and
Library.
Free Chat can stream from a selected hydrated LM Studio text route using the
OpenAI-compatible chat completions endpoint.

Real endpoint data is runtime configuration only. Do not commit private
Tailscale IPs, machine names, API keys, endpoint snapshots, or model inventory.

## Lucidity Fleet

`Fleet/` contains the self-hosted orchestration stack for the local inference
fleet: an orchestrator service (session routing, chat history mirroring,
machine health), an MCP diffusion server wrapping ComfyUI (callable by
opencode agents mid-session and by the phone), and a phone-first installable
PWA — all Tailscale-only. See `Fleet/README.md` for architecture, setup, and
GitLab CI.
