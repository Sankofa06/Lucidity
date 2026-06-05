# Lucidity — API & SDK Reference

> Verified developer reference for every integration Lucidity drives, so we get
> the REST calls, auth, streaming, and JSON contracts right the first time.
> Compiled June 2026. Items that couldn't be fetched live are marked
> **"verify"** — confirm against the linked docs before relying on them.
>
> **Big picture:** almost everything except Google Gemini speaks the **OpenAI
> Chat Completions wire format**, so one Swift HTTP client serves OpenAI, Qwen,
> xAI, OpenRouter, LM Studio, and Ollama by varying only **base URL + API key +
> model id**. Anthropic and Gemini each need their own adapter. All adapters
> emit Lucidity's common `ChatEvent` stream.

---

## Part A — Cloud LLM / image providers

### Anthropic (Claude)

- **Docs:** https://docs.anthropic.com · (no official Swift SDK → use raw HTTPS)
- **Base / endpoint:** `POST https://api.anthropic.com/v1/messages`
- **Auth + required headers:**
  - `x-api-key: <ANTHROPIC_API_KEY>`
  - `anthropic-version: 2023-06-01`
  - `content-type: application/json`
- **Models:** `claude-opus-4-8` (default, most capable), `claude-sonnet-4-6`,
  `claude-haiku-4-5`. Use exact IDs; do not append date suffixes.
- **Request (minimal):**
  ```json
  { "model": "claude-opus-4-8", "max_tokens": 16000,
    "messages": [{"role":"user","content":"Hello"}] }
  ```
- **Streaming (SSE):** add `"stream": true`. Event sequence: `message_start` →
  `content_block_start` → repeated `content_block_delta` (text in
  `delta.text` where `delta.type == "text_delta"`) → `content_block_stop` →
  `message_delta` (carries `stop_reason`, usage) → `message_stop`.
- **Thinking (Opus 4.6+):** adaptive only — `"thinking": {"type":"adaptive"}`.
  `budget_tokens`, `temperature`, `top_p`, `top_k` are **removed on Opus 4.8/4.7
  (400 if sent)**. Effort via `"output_config": {"effort": "high"}`
  (`low|medium|high|xhigh|max`).
- **Stop reasons:** `end_turn`, `max_tokens`, `tool_use`, `pause_turn`,
  `refusal` (check `stop_details`).
- **Gotchas:** roles must alternate, first message `user`; for `max_tokens` above
  ~16K, stream to avoid HTTP timeouts; tool-call `input` is JSON — parse it,
  don't string-match.

### OpenAI

- **Docs:** https://platform.openai.com/docs/api-reference/chat/create ·
  image: https://developers.openai.com/api/docs/guides/tools-image-generation
- **Base:** `https://api.openai.com`
  - Chat: `POST /v1/chat/completions`
  - Images: `POST /v1/images/generations`
- **Auth:** `Authorization: Bearer <OPENAI_API_KEY>` (optional
  `OpenAI-Organization` / `OpenAI-Project`).
- **Streaming (SSE):** `"stream": true`; each event `data: {json}`; terminates
  with literal `data: [DONE]`. Token text in `choices[0].delta.content` (note
  `delta`, not `message`).
- **Image request (gpt-image-1):**
  ```json
  { "model": "gpt-image-1", "prompt": "a red fox",
    "size": "1024x1024", "quality": "high" }
  ```
  - `size`: `1024x1024 | 1024x1536 | 1536x1024 | auto`; `quality`:
    `low|medium|high|auto`.
  - **gpt-image-1 always returns base64** in `data[0].b64_json` (no URL output;
    DALL·E 3 still supports `response_format:"url"`). Decode base64 off the main
    thread in Swift.
- **Gotchas:** split SSE on `\n\n`, strip `data: `, handle `[DONE]` before JSON
  decode; gpt-image-1 may require org verification.

### Google Gemini  *(only non-OpenAI-shaped provider — needs its own adapter)*

- **Docs:** https://ai.google.dev/api · generate-content:
  https://ai.google.dev/api/generate-content · video (Veo):
  https://ai.google.dev/gemini-api/docs/video
- **Base:** `https://generativelanguage.googleapis.com`
  - Generate: `POST /v1beta/models/{model}:generateContent`
  - Stream: `POST /v1beta/models/{model}:streamGenerateContent?alt=sse`
- **Auth:** header `x-goog-api-key: <KEY>` (preferred over legacy `?key=`).
- **Streaming:** **must** add `?alt=sse` or you get a buffered array instead of
  SSE (the #1 streaming bug). Each event `data: {GenerateContentResponse}`.
- **Request (minimal):**
  ```json
  { "contents": [ { "role":"user", "parts":[ { "text":"Explain AI briefly" } ] } ] }
  ```
  System prompt is a separate `systemInstruction` field; optional
  `generationConfig`, `safetySettings`, `tools`.
- **Response / chunk:** text at `candidates[0].content.parts[0].text`; roles are
  `user` / `model` (not `assistant`); `finishReason` + `usageMetadata`.
- **Image / video:** native image gen via `:generateContent` (bytes come back as
  a part with `inlineData.data` base64 + `mimeType`); **Imagen** dedicated:
  `POST /v1beta/models/{imagen}:predict` with
  `{"instances":[{"prompt":"…"}],"parameters":{…}}`; **Veo (video)** is async:
  `:predictLongRunning` then poll the operation. *(Model IDs move fast — verify.)*
- **Gotchas:** model id lives in the URL path with a `:method` suffix, not the
  body.

### Qwen — Alibaba Cloud Model Studio / DashScope

- **Docs:** OpenAI-compat:
  https://www.alibabacloud.com/help/en/model-studio/compatibility-of-openai-with-dashscope
- **OpenAI-compatible surface (use this — reuse the shared client):**
  - **Singapore / International** (matches the owner's "Qwen Studio Singapore
    Token Plan"): `https://dashscope-intl.aliyuncs.com/compatible-mode/v1`
  - China (Beijing): `https://dashscope.aliyuncs.com/compatible-mode/v1`;
    US: `https://dashscope-us.aliyuncs.com/compatible-mode/v1`
  - Endpoint: `POST /chat/completions`; body + SSE identical to OpenAI; models
    e.g. `qwen-plus`, `qwen-max`, `qwen3-…`.
- **Auth:** `Authorization: Bearer <DASHSCOPE_API_KEY>`.
- **Gotchas:** **keys + base URLs are region-locked** — a Singapore key only
  works on the `dashscope-intl` host. Use the `-intl` URL.

### xAI (Grok)

- **Docs:** https://docs.x.ai/docs/api-reference · image:
  https://docs.x.ai/docs/guides/image-generations
- **Base:** `https://api.x.ai/v1` (OpenAI-compatible)
  - Chat/vision: `POST /v1/chat/completions`; Images: `POST /v1/images/generations`
- **Auth:** `Authorization: Bearer <XAI_API_KEY>`.
- **Streaming:** SSE, OpenAI-identical.
- **Image:** `{"model":"grok-2-image","prompt":"…","n":1}` → JPG, OpenAI-shaped
  `data[]`.
- **Video:** ⚠️ **verify** — no documented public text-to-video endpoint as of
  now. For `/video`, treat xAI as unsupported until published; route video to
  Gemini/Veo or ComfyUI instead.

### OpenRouter (aggregator)

- **Docs:** https://openrouter.ai/docs/quickstart
- **Base:** `https://openrouter.ai/api/v1` (OpenAI-compatible)
  - Chat: `POST /api/v1/chat/completions`; List models: `GET /api/v1/models`
    (no auth needed to list).
- **Auth:** `Authorization: Bearer <OPENROUTER_API_KEY>`; optional
  `HTTP-Referer` + `X-Title` for attribution.
- **Model ids are namespaced** `provider/model`, e.g. `openai/gpt-5.4`,
  `anthropic/claude-sonnet-4`, `google/gemini-2.5-pro`. Optional `:free`,
  `:nitro`, `:floor` suffixes. The `provider/` prefix is mandatory.

### "Atlas (images)" — ⚠️ NEEDS OWNER CONFIRMATION

- The key label is ambiguous. **Most plausible:** **Atlas Cloud**
  (`atlascloud.ai`), a unified OpenAI-compatible gateway including image models.
  - Docs: https://www.atlascloud.ai/docs/en/models/image ·
    https://www.atlascloud.ai/developer
  - Likely base `https://api.atlascloud.ai/v1` (OpenAI-compatible
    `Authorization: Bearer` + `/chat/completions`, `/images/generations`).
    *(verify — docs were bot-blocked.)*
- **Rule out, don't assume:** Atlas by Nomic (`atlas.nomic.ai`, embeddings/viz —
  not image gen), OpenAI "Atlas" (a browser). **Ask the owner which dashboard /
  domain the key came from before wiring it.**

### Shared OpenAI-compatible client

One Swift client serves **OpenAI, Qwen (compatible-mode), xAI, OpenRouter,
LM Studio, Ollama** (likely Atlas Cloud too) by varying base URL + key + model
id. Request body (`{model, messages, stream}`), SSE framing
(`data: …\n\n` + `[DONE]`), and `choices[].delta.content` are identical.
**Anthropic and Gemini are the two exceptions** that need dedicated adapters.

---

## Part B — Local engines (over Tailscale)

> All four bind `127.0.0.1` by default — bind `0.0.0.0` / the Tailscale IP to
> reach them across the tailnet, and enable the relevant listen/CORS flags.

### LM Studio — port 1234

- **OpenAI-compatible (`/v1`):** `POST /v1/chat/completions` (SSE, `[DONE]`),
  `/v1/completions`, `/v1/embeddings`, `GET /v1/models`.
- **Enhanced REST (`/api/v0`, beta):** same shapes **plus** a `stats` block
  (`tokens_per_second`, `time_to_first_token`, `generation_time`, `stop_reason`),
  `model_info`, `runtime`. Use `/api/v0` when you want TTFT / tok-s.
- **Load/unload:** not a documented REST endpoint — app, `lms load/unload` CLI,
  or SDK; JIT auto-load on first request *(verify)*.
- **Gotchas:** server is off by default; `/v1` returns empty `"stats": {}`; first
  request to an unloaded model is slow (raise timeouts).

### Ollama — port 11434

- **Native:** `POST /api/chat`, `POST /api/generate`, `GET /api/tags`
  (list models), `POST /api/show`, `GET /api/ps`, `POST /api/pull`. Also
  OpenAI-compatible `/v1/chat/completions`.
- **Streaming = NDJSON** (`application/x-ndjson`) — newline-delimited, **no
  `data:` prefix, no `[DONE]`**. Each line has `message.content` (chat) or
  `response` (generate); the terminating line has `"done": true` + timings
  (**nanoseconds**).
- **Gotchas:** don't mix the NDJSON (`/api`) and SSE (`/v1`) parsers;
  `keep_alive` controls VRAM residency; set `OLLAMA_HOST=0.0.0.0:11434` for the
  tailnet.

### ComfyUI — port 8188

- **HTTP:** `POST /prompt` (needs `client_id` + **API-format** `prompt` graph →
  `{prompt_id, number, node_errors}`), `GET /history/{prompt_id}`,
  `GET /view?filename=&subfolder=&type=`, `GET /object_info`, `GET /queue`,
  `POST /interrupt`.
- **WebSocket:** `ws://host:8188/ws?clientId=<uuid>` — JSON `{type,data}` events:
  `status` (`queue_remaining`), `execution_start`, `execution_cached`,
  `executing` (**`node == null` ⇒ done**), `progress` (`value`/`max`),
  `executed` (carries `output.images[]` with `filename/subfolder/type`),
  `execution_success`, `execution_error`. Plus **binary** preview frames (4-byte
  event-type header + format code 1=JPEG / 2=PNG + bytes) — branch on
  `.string` vs `.data` in Swift.
- **Prompt → image mapping:** use one UUID for both `client_id` and ws
  `clientId` → `POST /prompt` → watch ws `progress` + `executing(node=null)` /
  `execution_success` → `GET /history/{prompt_id}` →
  `outputs.<node>.images[]` → `GET /view?…` for bytes.
- **Gotchas:** must send the **API-format** graph (not editor JSON); the UUID
  must match on both channels or you only get global `status`; needs
  `--listen 0.0.0.0`; only output nodes (SaveImage) appear in `outputs`.

### Automatic1111 / Forge — port 7860

- **REST:** `POST /sdapi/v1/txt2img`, `POST /sdapi/v1/img2img`,
  `GET /sdapi/v1/progress` (**poll-only, no websocket**),
  `GET /sdapi/v1/sd-models`, `GET|POST /sdapi/v1/options`,
  `POST /sdapi/v1/png-info`.
- **txt2img fields** (defaults): `prompt`, `negative_prompt`, `steps` (50),
  `width`/`height` (512), `batch_size` (1), `n_iter` (1), `sampler_name`,
  `cfg_scale` (7.0), `seed` (-1), `enable_hr`, `hr_scale` (2.0),
  `denoising_strength`. **Response:** base64 `images[]`, `parameters`, and
  `info` (a **stringified JSON** — double-parse for per-image seeds).
  img2img adds `init_images[]`, `denoising_strength` (0.75), `mask`.
- **Progress:** `/progress` → `progress` (0–1), `eta_relative`,
  `state.sampling_step/steps`, `current_image` (base64 live preview). txt2img /
  img2img **block** until done — poll `/progress` on a separate connection.
- **Gotchas:** requires the `--api` flag (else 404); total images =
  `batch_size * n_iter`; switch model per-request via
  `override_settings.sd_model_checkpoint` (avoids global state). **Forge** is
  `/sdapi/v1/*`-compatible — same client code; discover sampler names / option
  keys at runtime.

---

## Part C — Embedded inference (on-device)

### MLX-Swift / mlx-swift-lm  *(Apple silicon only)*

- **Repos:** github.com/ml-explore/mlx-swift (core),
  github.com/ml-explore/mlx-swift-lm (LLM/VLM libs — split out of the old
  `mlx-swift-examples`), github.com/ml-explore/mlx-swift-examples (sample apps).
  Models: huggingface.co/mlx-community.
- **SwiftPM:** add both packages; link `MLXLLM`, `MLXVLM`, `MLXLMCommon`,
  `MLXEmbedders`.
- **API:** `LLMModelFactory.shared.loadContainer(configuration:progressHandler:)`
  → `ModelContainer`; `try await container.perform { ctx in … }` (throwing, in
  `MLXLMCommon`); `MLXLMCommon.generate(input:parameters:context:) { tokens in
  .more / .stop }`; `UserInput`, `ctx.processor.prepare(input:)`.
- **Gotchas:** Apple-silicon only (Metal + unified memory); test on device
  (simulator GPU path unreliable); 4-bit quants on iOS; API has churned — **pin
  versions**.

### llama.cpp from Swift  *(cross-platform, CPU-capable)*

- **Repo:** github.com/ggml-org/llama.cpp (`tools/server/README.md`;
  `examples/llama.swiftui/LibLlama.swift`).
- **Option A — `llama-server`** (OpenAI-compatible HTTP): `/v1/chat/completions`,
  base `http://localhost:8080/v1`, SSE. Drive with plain URLSession — simplest,
  and reuses the shared OpenAI-compatible client.
- **Option B — in-process** via a SwiftPM binary xcframework target
  (`llama-b<NNNN>-xcframework.zip` + checksum) wrapping the C API
  (`llama_model_load_from_file`, `llama_decode`, sampler chain). Higher build /
  packaging complexity.
- **Gotchas:** GGUF models; pin to a `b<build>` tag (C API changes often). Keep
  in its own SPM target so build complexity doesn't leak.

---

## Part D — Apple platform & tooling

### SwiftData + CloudKit

- **Config:** `ModelConfiguration(..., cloudKitDatabase: .private("iCloud.<bundle>"))`.
  Capabilities: iCloud → CloudKit container; Background Modes → Remote
  notifications.
- **Model rules (all required, else sync fails silently):** every property
  optional or has a default; **no `@Attribute(.unique)` / unique constraints**;
  all relationships optional with an explicit inverse; **no `.deny` delete rule**;
  lightweight/additive migrations only; private DB only.
- **Source:** developer.apple.com/forums/thread/735349, fatbobman.com. Validate
  in the CloudKit console.

### Keychain Services (API keys)

- **API:** `SecItemAdd` / `SecItemCopyMatching` / `SecItemUpdate` /
  `SecItemDelete` (OSStatus). Class `kSecClassGenericPassword`; attrs
  `kSecAttrService`, `kSecAttrAccount`, `kSecValueData`, `kSecAttrAccessGroup`,
  `kSecAttrAccessible`.
- **Accessibility:** `WhenUnlocked` (default), `AfterFirstUnlock` (background
  access), `WhenPasscodeSetThisDeviceOnly` (most secure, never synced).
- **Notes:** device-local unless `kSecAttrSynchronizable=true` + iCloud Keychain
  (we keep secrets local). Upsert = delete-then-add (else `errSecDuplicateItem`);
  on macOS set `kSecUseDataProtectionKeychain`. Reference wrapper: KeychainAccess.

### Tailscale

- **Local discovery:** `tailscale status --json` → top-level `Self` + `Peer`
  (map by pubkey); each PeerStatus has `HostName`, `DNSName`, `TailscaleIPs[]`,
  `Online`, `OS`, `LastSeen`.
- **LocalAPI:** unix-socket interface between CLI and `tailscaled` (not a stable
  public REST API); `tailscale up [--authkey tskey-…]` *(verify)*.
- **REST API:** base `https://api.tailscale.com/api/v2`; **list devices:**
  `GET /api/v2/tailnet/-/devices` (`-` = default tailnet) → `{devices:[…]}`;
  single device: `GET /api/v2/device/{id}`. Auth: API key via Basic (key as
  username, empty password) or Bearer OAuth token. Docs: tailscale.com/api
  *(live page 403'd — endpoint shape is long-stable; verify)*.

### CivitAI

- **Base:** `https://civitai.com/api/v1`: `GET /models` (query / types / sort /
  period / nsfw / limit / page|cursor → `{items, metadata}`),
  `GET /models/{id}`, `GET /model-versions/{id}` (has `files[].downloadUrl` +
  hashes), `GET /model-versions/by-hash/{hash}`, `GET /images`.
- **Download:** `GET /api/download/models/{versionId}` → 302 to presigned S3.
- **Auth:** `Authorization: Bearer <key>` or `?token=<key>` (needed when the
  redirect strips headers); many downloads require a key. Cursor paging for deep
  lists (`page*limit > 1000` errors). Docs: developer.civitai.com.

### Hugging Face Hub

- **Base:** `https://huggingface.co`: search
  `GET /api/models?search=&filter=&sort=downloads&limit=&full=true`; info
  `GET /api/models/{repo_id}` (request `inferenceProviderMapping`); **file
  download** `…/{repo}/resolve/{revision}/{file}` → 302 to CDN.
- **Auth:** `Authorization: Bearer hf_…` (required for gated/private).
- **Inference:** OpenAI-compatible router base `https://router.huggingface.co/v1`,
  `POST /v1/chat/completions`; provider routing via model-id suffix
  (`:cheapest` / `:fastest` / `:provider`). Legacy:
  `api-inference.huggingface.co/models/{id}`.

---

## Verification status

- **Directly verified against live source/docs:** Ollama, ComfyUI (server
  source), A1111/Forge (processing source), MLX repo split, HF router base,
  SwiftData+CloudKit rules, CivitAI auth/download.
- **Verified via official search snippets (live page 403'd) — double-check:**
  OpenAI platform reference, Atlas Cloud, Tailscale REST device-list path, some
  LM Studio specifics.
- **From knowledge, verify:** xAI video support (assumed none), Tailscale
  LocalAPI specifics, LM Studio JIT auto-load.
- **Model IDs move fast** (e.g. `gpt-5.4`, `gemini-*`, `qwen3-*`) — confirm exact
  current IDs at request time, ideally via each provider's `/models` endpoint.
