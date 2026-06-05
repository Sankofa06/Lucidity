# Lucidity — Product Requirements Document

> **Status:** Draft · **Owner:** mdwilliams1989 · **Date:** 2026-06-05
> **Tagline:** Better LM Manager Pro — one calm surface for every AI workload across all your machines.

## 1. Problem

AI workloads are scattered. Chat models run in LM Studio or Ollama on one box,
image and video pipelines run in ComfyUI or Automatic1111 on a GPU machine, and
the best frontier models live behind cloud APIs. Each has its own app, port, and
quirks. There is no single place to talk to all of them, route work to the right
machine, and let long jobs finish on their own.

## 2. Vision

Lucidity is a **unified control surface for AI** across a person's own fleet of
machines. The phone or Mac is a **client** that drives a **mesh of compute** —
Macs and Windows/Linux GPU boxes — discovered over Tailscale. Lucidity also runs
its own on-device inference. Everything is reachable, observable, and
composable from one calm, modular interface.

## 3. Goals & non-goals

**Goals**
- One surface to drive local engines, cloud APIs, and on-device inference.
- A distributed mesh where models can live on any machine and run concurrently.
- Long-running jobs (e.g. 48 images from one prompt) finish in the background
  and survive the client disconnecting.
- Bring-your-own-keys for cloud and tooling providers, stored securely.
- Optional, free sync of personal data across the user's Apple devices.

**Non-goals (for now)**
- Multi-tenant / team-cloud hosting. This is personal infrastructure.
- A hosted backend we have to operate. Sync rides on CloudKit.
- Replacing the engines themselves — Lucidity orchestrates, it doesn't reimplement.

## 4. Users

- **The power user / builder** running several AI tools across personal machines
  who wants one remote control instead of five apps and a pile of ports.
- **The mobile operator** who wants to kick off heavy generation from a phone and
  walk away while a desktop GPU does the work.

## 5. Experience principles

- **Calm and modular.** Small, focused screens; nothing overwhelming.
- **One entry point.** A chat surface is the universal way to start any workload.
- **Background by default.** Heavy work runs to completion without babysitting.
- **Your keys, your machines.** Local-first, private, no required cloud account.

## 6. Core concepts

- **Node** — a machine in the mesh (Mac, PC, GPU box), identified via Tailscale.
- **Host** — the Lucidity service running on a node; advertises capabilities and
  runs jobs.
- **Capability connector** — a per-engine helper on a Host that auto-discovers a
  live engine by its port (LM Studio, ComfyUI, A1111, Ollama). Dedicated per
  machine so nodes never interfere and run concurrently.
- **Provider** — a cloud or local model endpoint (Anthropic, OpenAI, Gemini,
  Qwen, Atlas, plus an aggregator and custom plug-ins).
- **Job** — a unit of work (chat, image batch, video render) that is durable,
  observable, and resumable.
- **Persona / Team / Workflow** — reusable configurations the user composes and
  (optionally) syncs.

## 7. Requirements

### 7.1 Functional
- **Unified chat** that can initiate any workflow: local LM Studio chat, cloud
  chat, and A1111 + ComfyUI image/video — all from one window.
- **Mesh discovery** via Tailscale; each machine exposes capabilities by port;
  concurrent, non-interfering execution across machines.
- **Background jobs** with live progress (and thumbnails for image batches) that
  stream back into the chat transcript and survive client disconnects.
- **Embedded inference** on-device, supporting both MLX and llama.cpp/GGUF
  behind one interface.
- **Provider management** — Anthropic, OpenAI, Gemini, Qwen, Atlas at launch;
  an OpenRouter-style aggregator and a generic custom-provider path for new
  engines (e.g. an on-device "ovi").
- **Secure key storage** for model providers and tooling (Tailscale, ComfyUI,
  CivitAI, HuggingFace) in the system keychain.
- **Optional sync** of personas, teams, workflows, and chat history across the
  user's Apple devices, toggleable on/off.

### 7.2 Non-functional
- **Platforms:** iOS + macOS clients; Host service on macOS first, cross-OS later.
- **Architecture:** MVVM / Clean, deeply modular, very small single-purpose
  files, natural-language naming, easy to search.
- **Privacy:** local-first; no required account; secrets stay on-device.
- **Resilience:** jobs live on the Host so phone limits never kill long work;
  graceful handling when a node is unreachable.

## 8. First milestone (the vertical slice)

A single, rock-solid, hyper-modular **Chat window** that can drive **everything**
from one surface:
- chat with a **local LM Studio** model,
- chat with a **cloud** provider using the user's key,
- generate images/video via **Automatic1111** and **ComfyUI**,
- with multi-image batches running as **background jobs** whose progress and
  results appear inline in the conversation.

This proves the end-to-end spine — providers, connectors, jobs, and the chat
surface — before broader workflows are added.

## 9. Phased roadmap

1. **Chat vertical slice** — the milestone above (jobs run client-side initially).
2. **Host daemon + mesh** — Tailscale discovery, per-machine connectors, move
   work behind Hosts.
3. **Durable jobs at scale** — persistent queue, checkpoints, crash-resume,
   large batches surviving disconnect; a jobs dashboard.
4. **Embedded inference** — MLX, then llama.cpp/GGUF, with model management.
5. **Sync** — CloudKit sync of personal data, toggleable.
6. **More providers & workflows** — Gemini, Atlas, aggregator, custom plug-ins,
   CivitAI/HuggingFace browsing, saved workflows, video.

## 10. Open questions

- Second sync option to complement CloudKit (to be discussed).
- Cross-OS Host strategy for Windows/Linux GPU boxes (Linux first, then Windows).
- Which embedded engine ships first if we sequence MLX vs llama.cpp.

## 11. Success criteria

- A user can, from one chat window, complete a text chat (local and cloud) and
  kick off an image batch on a remote machine that finishes in the background
  and shows up in the conversation — without touching any underlying tool's UI.
