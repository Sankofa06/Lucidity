# Mira Product Requirements Document

> Status: First-build blueprint
> Owner: mdwilliams1989
> Updated: 2026-06-05
> Bundle ID: `com.michaelwilliams.mira`

## Problem

AI work is scattered across local chat servers, cloud APIs, media engines, model
source sites, and several personal machines. A user may have LM Studio on
multiple Macs or Windows boxes, ComfyUI on a GPU desktop, A1111/Forge on another
port, and cloud models behind separate keys. Each tool has its own UI and
endpoint rules. Mira provides one native chat-first studio that can choose,
inspect, and orchestrate those routes without forcing the user to remember ports
or leave the conversation.

## Vision

Mira is a chat-first AI studio for local machines, cloud models, media engines,
model sources, personas, teams, projects, and persistent sessions. The app opens
to Chat, with a responsive Inspector and a Claude-style rail/drawer for fast
navigation. Chat is the main control surface; Settings, Library, Model Sources,
Machines, Personas, Teams, and Projects support that flow.

## Experience Principles

- Chat is the center. All major workflows can begin from chat.
- The picker is task-first, not a wall of models.
- Inspector depth is always nearby, but never clutters small screens.
- Diagnostics are visible and beautiful: health chips, progress bars, route
  glows, queues, and live operational indications.
- Developer Mode reveals internals without making the normal app feel technical.
- Real endpoint data is user-owned configuration, never source constants.

## Main Views

- **Chat**: Free Chat, Group Chat, Compare, Create Media, Inspect, and Workflow.
- **Inspector**: an elegant AI-studio dashboard for the selected chat/task/route.
- **Projects**: lightweight containers for sessions, personas, teams, routes,
  workflows, and source/library context.
- **Personas**: chat and media-capable persona creation and editing.
- **Teams**: ordered or parallel groups of personas.
- **Library**: local inventory of machines, endpoints, models, checkpoints,
  LoRAs, workflows, saved routes, and source-linked assets.
- **Model Sources**: Hugging Face and CivitAI source layer for keys, metadata,
  download planning, installed-file matching, licenses, trigger words, and
  persona/route attachment.
- **Machines**: manual/Tailscale machines, expected endpoint ports, refresh,
  probe diagnostics, and discovered routes.
- **Settings**: organized first-class settings hub.

## Navigation And Layout

Mira uses a compact Claude-style rail/sliding drawer. Chat remains central while
the rail gives fast access to Projects, Personas, Teams, Library, Sources,
Machines, and Settings.

Responsive behavior:

- iPhone portrait: chat is primary; inspector and rail open as sheets/drill-ins.
- iPhone landscape: compact chat plus inspector when there is enough width.
- iPad/Mac wide: chat and inspector side-by-side.
- iPad/Mac narrow: collapses cleanly to the iPhone layout.

Important actions should stay within 3-4 taps/clicks. If a workflow gets deeper,
prefer a contextual chip, inspector card, command palette, or alternate route
instead of another nested screen.

## Chat Tasks

- **Chat**
  - Free Chat: one route or persona.
  - Group Chat: multiple personas through ordered or parallel run steps.
  - Compare: same prompt across multiple routes side-by-side.
- **Create Media**
  - Image, GIF/animation, video, and edit/transform through one media planner.
- **Inspect**
  - Endpoint, machine, model, checkpoint, queue, settings, logs.
- **Workflow**
  - Saved multi-step plans and ComfyUI/A1111 payload builders.

Fresh chat cannot send until a task/route is selected. Free Chat, Group Chat,
Compare, media planning, endpoint inspection, and workflows use the same
orchestration engine.

First live chat implementation: Free Chat can stream one response from an
explicitly selected hydrated LM Studio text route. Group Chat, Compare,
transcript persistence, and cloud chat streaming remain planned follow-ups.

## Internal Engine

User-facing language stays simple: task, route, plan, progress, result.
Developer Mode can expose internal terms:

- `SmartRoute`
- `SmartRun`
- `RunStep`
- `InventorySnapshot`
- `RouteValidator`
- `RunScheduler`
- `RunConcurrencyPolicy`

Text routes may run broadly in parallel across machines and cloud providers.
Heavy media jobs do not run multiple image/video engines on the same machine in
parallel by default. Cross-machine media jobs can run in parallel. Multi-route
results appear grouped by machine/engine.

## Target Picker

The target picker is task-first and searchable. A selectable route combines:

- friendly name
- optional user alias
- machine
- endpoint
- engine/provider
- model/checkpoint/workflow
- health
- capabilities

Filters include online/offline, loaded/unloaded, machine, engine/provider,
local/cloud/on-device, text/image/video/GIF, reasoning, vision, context,
checkpoint, LoRA, ControlNet, AnimateDiff, cost, speed, pinned, recent, and tags.

## Machine Inventory

The first user-facing inventory workflow lets users add/edit machine display
names, hosts, and expected ports in-memory, then run read-only probes. Default
public fixtures use example hosts; real hosts must be entered at runtime or kept
in ignored local development config. Refreshed inventory hydrates machines,
endpoints, routes, diagnostics, Chat route picker content, Inspector developer
details, Machines status, and Library counts.

## Advisor

Advisor is a contextual Help chip near eligible inputs. It can help with prompts,
route selection, settings, LoRAs, checkpoints, workflow planning, diagnostics,
persona creation, and team setup.

The user chooses the default Advisor model in Settings. Advisor receives
structured inventory and returns structured plans. Mira validates every plan.
Default behavior is suggest-with-explanation and confirm. Trusted Mode lives
inside Developer Settings, defaults off, and may later allow auto-run for
validated plans.

## Inspector

Inspector is an AI-studio dashboard, not a raw tree. It shows:

- selected task/route summary
- machine health
- endpoint status
- selected model/checkpoint/workflow
- persona/team quick actions
- diagnostics indicators
- progress bars when progress is available or reconstructable
- operational glow while routes are responding/running

Developer Mode adds raw metadata, request/response previews, run steps,
validation details, inventory snapshots, timing, logs, and background events.

## Personas, Teams, Projects, Sessions

Projects are lightweight first-class containers. Persistent sessions are
first-class.

Personas can be created from the Inspector or Persona hub. A persona may include
name, role, optional character/personality, system prompt blocks, model/route
defaults, provider/API-supported settings, web search setting, memory setting,
media settings, and ComfyUI/A1111 workflow payload settings. Adding media
capability expands the persona's available settings. Personas can be added to
teams. Teams use the same run engine as Group Chat and Compare.

## Model Sources

Hugging Face and CivitAI are first-class Model Sources. The first build includes
source model types, settings/key placeholders, shell UI, local metadata concepts,
installed-file/source-link concepts, and attachment concepts. Later work adds
search/download, preview images, trigger words, license metadata, source-to-file
matching, and direct route/persona/workflow attachment. Keys live in Keychain
when functional.

## Settings

Settings sections:

- General
- Appearance & Themes
- Machines & Endpoints
- Cloud Providers & API Keys
- Model Sources
- Advisor
- Personas & Teams
- Projects & Sessions
- Developer Mode
- Trusted Mode
- Diagnostics & Logs
- Privacy & Sync
- App Store / Release Info

Theme customization starts with tokens for color, typography, spacing, sizing,
glow/intensity, and surface depth. A full user theme customizer is deferred.

## Background, App Intents, Live Activities

Mira does not rely on iOS for indefinite background work. Long media jobs should
eventually live on host machines; iOS observes and reattaches. The first build
adds architecture hooks: stable run IDs, deep-linkable chat/run state,
extension-safe run state, App Entity shapes, and Live Activity-ready progress
models. Later App Intents can start chat, inspect endpoints, create media, run
workflows, and open active runs. Later Live Activities can show job progress and
deep-link to the exact chat/run.

## First Build Success Criteria

- The app builds as `Mira` with bundle ID `com.michaelwilliams.mira`.
- Chat opens as the main surface.
- The rail/drawer can navigate all planned first-class areas.
- Inspector, Settings, task picker, route picker, personas, teams, projects,
  library, sources, machines, and diagnostics have polished shells.
- Domain models and tests cover routes, runs, personas, projects, settings,
  diagnostics, model sources, and concurrency policy.
- Endpoint architecture exists for read-only LM Studio, A1111/Forge, ComfyUI,
  Hugging Face, and CivitAI work.
- No real private endpoints, keys, or machine inventory are committed.
