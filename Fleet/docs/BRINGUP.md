# Bring-up checklist

A staged path to a working system. Each stage ends with a concrete check —
don't move to the next stage until that check passes. You do not need all
four stages to get value: Stage 1 alone is a working phone-to-agent chat
system.

## Mental model

Three kinds of process, total:

1. **`opencode serve`** — one per coding machine, using that machine's own
   LM Studio as its model provider. You never talk to these directly.
2. **Orchestrator (:8780) + diffusion server (:8790)** — both run on the
   always-on machine (Mac Mini in the default layout). The orchestrator is
   the hub: it polls the opencode instances, routes/mirrors sessions, and
   serves the PWA. The diffusion server wraps ComfyUI, wherever ComfyUI runs.
3. **Your phone** — talks only to the orchestrator, never directly to
   opencode or ComfyUI.

`phone → orchestrator → { opencode instances, diffusion server → ComfyUI }`

ComfyUI does **not** need to be on the same machine as the orchestrator —
see "Notes" below.

## Stage 1 — one machine, chat working end to end

On the always-on machine (Mac Mini in the default layout):

```bash
# LM Studio: Developer tab → start server (port 1234) → load a model.

npm i -g opencode-ai
mkdir -p ~/.config/opencode
cp Fleet/opencode/opencode.example.jsonc ~/.config/opencode/opencode.json
# Edit: list this machine's actual LM Studio model ID(s) under "models".
# Delete/ignore the "mcp" block for now — that's Stage 3.

cd Fleet
./deploy/macos/install.sh opencode        # opencode serve on :4096

npm ci && npm run build
cp config/fleet.example.json ../LocalDev/fleet.local.json
# Edit LocalDev/fleet.local.json: set this machine's real Tailscale
# MagicDNS name (`tailscale status`) as the "host" for its entry.
# Leave the other machine entries in place — they'll just show offline.

./deploy/macos/install.sh orchestrator
```

**Check:** `curl localhost:8780/api/fleet` shows this machine with
`opencodeOnline: true` and your LM Studio models listed. Then, phone on the
tailnet: open `http://<tailnet-name>:8780`, Add to Home Screen, **+ New
session**, send a message, watch it stream back.

## Stage 2 — add the other machines (chat on all three)

On each additional machine: LM Studio server on 1234 with a model loaded →
`npm i -g opencode-ai` → copy the same `opencode.json`, adjust its model list
→ run as a service (`install.sh opencode` on macOS,
`install.ps1 -Unit opencode` on Windows). Fix that machine's `host` in
`fleet.local.json` on the orchestrator machine — no restart needed, the Fleet
tab flips green within ~15s.

## Stage 3 — images

Wherever ComfyUI runs: start it with `--listen 0.0.0.0` (or
`install.ps1 -Unit comfyui` on Windows), confirm a checkpoint is present.
On the orchestrator machine:

```bash
./deploy/macos/install.sh mcp-diffusion http://<comfy-tailnet-name>:8188
```

If your checkpoint isn't SDXL base, set `COMFY_CHECKPOINT` in the generated
plist to your actual filename.

**Check:** `curl localhost:8790/api/health` shows `comfyOnline: true`;
generate an image from the phone's Images tab.

Then add the `mcp` block back to every machine's `opencode.json`, pointing at
`http://<orchestrator-tailnet-name>:8790/mcp`, and restart opencode on each —
agents can now generate images mid-session too.

## Stage 4 (optional) — GitLab CI

Nothing above depends on this. Push the repo to GitLab, register a runner per
machine (see `Fleet/README.md`, "GitLab CI"), and get one-button redeploys
from the GitLab UI on your phone. Skip until the system has earned it.

## Notes

- **ComfyUI does not need to be co-located with the orchestrator.** The
  diffusion server talks to `COMFY_URL` over plain HTTP + WebSocket — that's
  just a config value (`install.sh mcp-diffusion <comfy-url>`). Put ComfyUI
  on any tailnet machine, including a fourth one.
- **Debugging an offline machine** is always one of: process not running
  (`launchctl list | grep lucidity`; logs in `~/Library/Logs/lucidity/`),
  bound to `127.0.0.1` instead of `0.0.0.0`, or a `host` in
  `fleet.local.json` that doesn't match `tailscale status`. Sanity check with
  `curl http://<host>:4096/config/providers` from the orchestrator machine.
