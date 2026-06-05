# Mira Task Ledger

Canonical task ledger for the first build.

## done

### BUILD-001 - First build foundation

- type: implementation
- goal: Create Mira's documentation, Xcode project, domain foundation, polished
  chat-first UI shell, first-class settings, persona/team/project shells,
  Advisor/Developer Mode shell, endpoint architecture, tests, commits, and push.
- definition of done: The app builds with XcodeBuildMCP, core tests pass,
  documentation is current, private endpoint data is not committed, and verified
  slices are committed.
- verification: `xcodegen generate`, XcodeBuildMCP build/test, screenshot sanity
  check, `git diff --check`.
- status: done

## in-progress

None.

## ready

### BUILD-002 - Live endpoint probing

- type: stretch
- goal: Add read-only endpoint probing from ignored local dev config after the
  foundation is stable.
- definition of done: Probes LM Studio, A1111/Forge, and ComfyUI read-only
  endpoints without committing private data.
- verification: Mock URL tests, route hydration tests, XcodeBuildMCP build/test.
- status: done
- note: Read-only HTTP clients, endpoint probe service, route hydrator, mock
  provider, local config provider, and app-state refresh path exist.

### BUILD-004 - Manual machine settings UI

- type: implementation
- goal: Let users add, edit, and refresh configured machines from Settings or
  Machines without relying on local dev config.
- definition of done: User-entered machines can refresh inventory and hydrate
  chat routes without private source constants.
- verification: View-model tests, mock probe tests, XcodeBuildMCP build/test.
- status: done
- note: Machines now has in-memory editable drafts, port presets, read-only
  refresh, probe result diagnostics, and Settings entry points. Chat route
  picker, Inspector, Machines, and Library read the refreshed inventory.

### BUILD-003 - LM Studio live chat streaming

- type: stretch
- goal: Attempt first live LM Studio streaming chat after route/UI foundation is
  verified.
- definition of done: One selected LM Studio route can stream a response into
  the chat transcript.
- verification: Mock SSE test and optional local smoke test.
- status: ready

### BUILD-005 - Durable machine persistence

- type: implementation
- goal: Persist configured machines locally after the in-memory workflow is
  verified.
- definition of done: User-entered machine drafts survive app relaunch without
  storing private data in source control.
- verification: Persistence tests, migration/default tests, XcodeBuildMCP
  build/test.
- status: ready

## blocked

None.
