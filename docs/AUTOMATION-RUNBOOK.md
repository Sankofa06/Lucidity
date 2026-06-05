# Mira Automation Runbook

## First-Build Loop

1. Update docs with the current slice.
2. Regenerate the Xcode project with `xcodegen generate` when `project.yml`
   changes.
3. Run focused tests.
4. Use XcodeBuildMCP for clean warning-free builds.
5. Run `git diff --check`.
6. Commit the verified slice with a concise imperative message.
7. Push after the final verified first-build slice.

## Private Data

- Use `LocalDev/*.local.json` for real machine smoke testing.
- Do not commit Tailscale IPs, private machine names, API keys, endpoint
  snapshots, model inventories, or private logs.
- Keep committed examples fake and safe.

## Release Path

The first build stops before App Store submission. TestFlight is planned after
signing, App Store Connect records, screenshots, privacy/support docs, and
release readiness are confirmed.
