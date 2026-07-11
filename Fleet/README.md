# Lucidity Fleet

Self-hosted orchestration for a Tailscale-only local inference fleet: agentic
coding via [opencode](https://github.com/anomalyco/opencode) + LM Studio on
three machines, image generation via ComfyUI, all driven from a phone-first
PWA.

```
                      ┌────────────────────────────────────────────┐
   Phone (PWA)        │            M4 Mac Mini (always on)         │
  ┌───────────┐  SSE  │  ┌──────────────┐      ┌────────────────┐  │
  │ Lucidity  │◄──────┼──┤ orchestrator │◄────►│ mcp-diffusion  │  │
  │  PWA      ├───────┼─►│ :8780 SQLite │ REST │ :8790  /mcp    │  │
  └───────────┘ HTTPS │  └──┬───────┬───┘      └───────┬────────┘  │
   (tailnet only)     │     │       │                  │           │
                      │     │       ▼                  │           │
                      │     │  opencode serve :4096    │           │
                      │     │  + LM Studio :1234       │           │
                      └─────┼──────────────────────────┼───────────┘
        /event SSE + REST   │                          │ ComfyUI HTTP + WS
            ┌───────────────┴───────────┐              ▼
            ▼                           ▼         ┌───────────────────┐
  ┌───────────────────┐      ┌───────────────────┤ RTX 4070 Windows  │
  │ M5 MacBook Pro    │      │ RTX 4070 Windows  │ ComfyUI :8188     │
  │ opencode :4096    │      │ opencode :4096    │ (--listen)        │
  │ LM Studio :1234   │      │ LM Studio :1234   └───────────────────┘
  └───────────────────┘      └───────────────────┘
```

Every opencode instance also registers the MCP diffusion server
(`http://<mini>:8790/mcp`), so **agents can generate images mid-session**
("generate a reference texture for this component") without leaving the
coding session — the same engine the PWA's Images tab uses.

## Components

| Directory | What it is |
| --- | --- |
| `orchestrator/` | Node 22 + Express + SQLite. Machine discovery/health, session routing + mirroring, chat history, diffusion proxy, PWA host, `/api/events` SSE. |
| `mcp-diffusion/` | Node 22. MCP Streamable-HTTP server (`/mcp`) for agents + REST/SSE (`/api`) for the orchestrator, wrapping ComfyUI (jobs, queue, progress, images persisted to disk). |
| `pwa/` | React + Vite installable PWA: Chat, Images, Fleet tabs. Talks **only** to the orchestrator. |
| `shared/` | Wire types + SSE helpers shared by the two services. |
| `config/` | `fleet.example.json` — copy to `LocalDev/fleet.local.json` (git-ignored) with real tailnet hosts. |
| `opencode/` | Example `opencode.json` (LM Studio provider + MCP registration) for every machine. |
| `deploy/` | launchd units + installer for macOS, Scheduled Task installer for Windows. |

## Architecture decisions (and how to override them)

1. **Single orchestrator on the Mac Mini.** One SQLite DB is the source of
   truth for sessions/history; no distributed state. If the Mini is down the
   UI is down (agents on other machines keep running). To re-home it, install
   the same units on another machine and move `~/.lucidity-fleet/`.
2. **Sessions are pinned to their origin machine.** opencode sessions operate
   on that machine's filesystem, so they cannot migrate. The orchestrator
   mirrors every message into SQLite via each machine's `/event` stream, so
   history is readable from the phone even when the machine is offline.
   **Continue elsewhere** (↪ in the chat header) is an explicit action that
   creates a *new* session on another machine seeded with the transcript
   (recency-truncated at ~24k chars) — files and tool state do not follow.
3. **SSE, not WebSockets.** `EventSource` auto-reconnects and resumes via
   `Last-Event-ID` (the orchestrator replays a 500-event ring buffer), which
   is exactly the behavior a flapping cellular Tailscale link needs. The PWA
   also forces a reconnect + full refetch when returning to the foreground.
4. **Tailscale is the trust boundary.** Everything binds `0.0.0.0` but is only
   reachable inside the tailnet. No OAuth. An *optional* shared token
   (`token` in fleet config / `FLEET_TOKEN` env on the diffusion server, set
   in the PWA's ⚙ settings) adds defense-in-depth if you ever share the
   tailnet; leave it unset otherwise.
5. **The diffusion service is one process with two faces**: MCP for agents,
   REST+SSE for the orchestrator — one ComfyUI client, one job queue, one
   image store, no duplicated logic.
6. **Gallery persistence** is the diffusion server's `jobs.jsonl` + images
   directory (chat history lives in orchestrator SQLite). Simple, greppable,
   and images are plain files on disk.

## Setup

New to this stack? Start with **[`docs/BRINGUP.md`](docs/BRINGUP.md)** — a
staged checklist (one machine chatting → add the rest → images → optional
CI), each stage with a concrete pass/fail check. The rest of this section is
the reference version of the same steps.

### 0. Tailscale (all machines + phone)

- Install Tailscale everywhere and join the same tailnet; enable
  **MagicDNS** so machines have stable names (`your-mini.your-tailnet.ts.net`).
- No `tailscale serve`/`funnel`, no port forwarding — services bind 0.0.0.0
  and are reachable only inside the tailnet.
- Optional hardening: Tailscale ACLs restricting ports 4096/8188/8780/8790 to
  your own devices.

### 1. Per-machine: LM Studio + opencode (all three)

1. LM Studio → Developer/Server: enable the OpenAI-compatible server on
   port 1234 (localhost is fine — only the machine's own opencode talks to it).
2. Install opencode: `brew install anomalyco/tap/opencode` (macOS) or
   `npm i -g opencode-ai` (both platforms).
3. Copy `Fleet/opencode/opencode.example.jsonc` to
   `~/.config/opencode/opencode.json`, list that machine's actual LM Studio
   models, and point the `mcp.diffusion.url` at the Mini's real tailnet name.
4. Run it as a service:
   - macOS: `Fleet/deploy/macos/install.sh opencode`
   - Windows: `Fleet/deploy/windows/install.ps1 -Unit opencode`

### 2. ComfyUI (RTX 4070 box, or any other tailnet machine)

ComfyUI does not need to run on the same machine as the orchestrator — the
diffusion server below just needs a `COMFY_URL` it can reach over the
tailnet. ComfyUI must listen on the tailnet, not just localhost:
`python main.py --listen 0.0.0.0 --port 8188`, or install it as a task:
`Fleet/deploy/windows/install.ps1 -Unit comfyui -ComfyDir C:\ComfyUI -ComfyPython C:\ComfyUI\venv\Scripts\python.exe`.

### 3. Mac Mini: orchestrator + mcp-diffusion

```bash
cd Fleet
npm ci && npm run build
cp config/fleet.example.json ../LocalDev/fleet.local.json   # then edit real hosts
./deploy/macos/install.sh mcp-diffusion http://your-rtx-box.your-tailnet.ts.net:8188
./deploy/macos/install.sh orchestrator
```

Environment knobs for the diffusion service (set in its plist if needed):
`COMFY_URL`, `COMFY_CHECKPOINT` (default `sd_xl_base_1.0.safetensors`),
`DIFFUSION_PORT` (8790), `DIFFUSION_DATA_DIR`, `DIFFUSION_WORKFLOWS_DIR`,
`DIFFUSION_GENERATE_TIMEOUT_MS`, `FLEET_TOKEN`.

Custom ComfyUI workflows: export a workflow in **API format**, replace the
values you want parameterized with `%%PROMPT%%`, `%%NEGATIVE_PROMPT%%`,
`%%SEED%%`, `%%STEPS%%`, `%%CFG%%`, `%%WIDTH%%`, `%%HEIGHT%%`,
`%%CHECKPOINT%%`, `%%SAMPLER%%`, `%%BATCH_SIZE%%`, and drop it as
`<name>.json` into the workflows dir. It appears in the PWA's workflow picker
and in the agents' `list_workflows` tool.

### 4. Phone

Open `http://your-mini.your-tailnet.ts.net:8780` in the phone browser (with
Tailscale connected) → Share/Menu → **Add to Home Screen**. The app shell is
cached by a service worker, so it opens instantly even before the tailnet
reconnects.

## GitLab CI

Host the repo on GitLab (gitlab.com or self-hosted). `.gitlab-ci.yml` at the
repo root defines:

- `fleet:test` — lint/build/test on shared runners, on any change under `Fleet/`.
- `deploy:mini`, `deploy:macbook`, `deploy:rtx4070` — **manual** jobs that run
  on self-hosted shell runners registered on each machine (shared runners
  can't reach the tailnet). One-button deploys from the GitLab UI on the phone.

Register a runner per machine:

```bash
# macOS (Mini shown; use lucidity-macbook on the MacBook)
brew install gitlab-runner
gitlab-runner register --executor shell --tag-list lucidity-mini \
  --url https://gitlab.com --token <runner-token>
brew services start gitlab-runner
```

```powershell
# Windows
gitlab-runner.exe register --executor shell --tag-list lucidity-rtx4070 `
  --url https://gitlab.com --token <runner-token>
gitlab-runner.exe install; gitlab-runner.exe start
```

No runners yet? Deploy by hand: `git pull && cd Fleet && npm ci && npm run
build && ./deploy/macos/restart-services.sh` (macOS) or the PowerShell
equivalent.

## Development

```bash
cd Fleet
npm ci
npm run build              # all workspaces
npm test                   # vitest (orchestrator + mcp-diffusion)
npm run dev -w orchestrator    # tsx watch (needs FLEET_CONFIG or LocalDev config)
npm run dev -w mcp-diffusion
npm run dev -w pwa             # Vite dev server, proxies /api to :8780
```

## API sketch (orchestrator, all under `/api`)

- `GET /fleet`, `POST /fleet/refresh`, `POST /machines/:id/adopt-sessions`
- `GET|POST /sessions`, `GET|PATCH|DELETE /sessions/:id`
- `POST /sessions/:id/messages` (202; replies stream via SSE), `POST /sessions/:id/abort`
- `POST /sessions/:id/continue` `{machineId}`
- `GET /events` — SSE: `fleet.status`, `session.*`, `message.updated`,
  `message.part.delta`, `diffusion.job`
- `GET|POST /diffusion/jobs`, `POST /diffusion/jobs/:id/cancel`,
  `GET /diffusion/workflows`, `GET /diffusion/images/:filename`

MCP tools exposed to agents: `generate_image`, `get_job_status`, `get_image`,
`list_jobs`, `list_workflows`, `get_queue_state`.

## Troubleshooting

- **Machine shows offline** — is `opencode serve` running and bound to
  `0.0.0.0`? `curl http://<host>:4096/config/providers` from the Mini.
- **Diffusion offline** — the badge means orchestrator→mcp-diffusion→ComfyUI
  end-to-end. Check `curl http://<mini>:8790/api/health` (`comfyOnline` field)
  and that ComfyUI was started with `--listen`.
- **Model missing in the picker** — it must be listed in that machine's
  `opencode.json` under the `lmstudio` provider (opencode reports models from
  config, not from what LM Studio has loaded; the Fleet tab shows loaded
  models separately).
- **Phone won't reconnect after a network flap** — background the app and
  reopen (forces SSE reconnect + refetch), or tap the reconnect banner.
- Logs: `~/Library/Logs/lucidity/*.log` (macOS),
  `%USERPROFILE%\lucidity-logs` + Task Scheduler history (Windows).
