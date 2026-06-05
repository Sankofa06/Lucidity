# Repository Guidelines

## Project Structure & Module Organization

Mira is a Swift 6 iOS app project. The repository is currently minimal, so keep the future layout explicit and modular:

- `Mira/` for app source, SwiftUI views, view models, domain logic, services, and assets.
- `MiraTests/` for fast unit tests.
- `MiraUITests/` for UI, screenshot, and end-to-end tests.
- `project.yml` for XcodeGen once the Xcode project is introduced.
- `fastlane/` or equivalent release automation for App Store Connect and TestFlight workflows.

Prefer small feature modules over broad shared folders. Keep documentation at the repository root unless it belongs to a specific module.

## Architecture & Purity

Use pure SwiftUI MVVM + Services by default. Views are presentation-only. View models own UI state and coordination. Services perform side effects behind injected protocols. Domain and business logic should be pure functions wherever practical.

Files must not mix architectural roles. If a change would require a view, view model, service, or domain type to violate its responsibility, stop and identify refactor options before implementing.

## Karpathy Guidelines

Apply Karpathy-style coding guardrails to all non-trivial work in this repo:

- Think before coding. State material assumptions, surface ambiguity, and push back when a simpler path satisfies the goal.
- Prefer the simplest sufficient implementation. Avoid speculative features, broad abstractions, or configurability that was not requested.
- Make surgical changes. Every changed line should trace to the task, and unrelated refactors, formatting churn, or cleanup should be left alone unless explicitly requested.
- Work from success criteria. Convert vague tasks into verifiable outcomes and keep looping until the agreed checks pass or the concrete blocker is reported.

These guardrails complement, not replace, Lucidity's stricter requirements for clean builds, zero warnings, current documentation, thoughtful versioning, commit readiness, and push readiness.

## Source File Standards

Keep files small, lightweight, and focused on one primary responsibility. Use Swift naming conventions: types in `UpperCamelCase`, functions and properties in `lowerCamelCase`, and enum cases in `lowerCamelCase`. Use 4-space indentation.

Every source file must begin with a helpful comment header covering:

- What the file is.
- What it does.
- What it touches.
- What touches it.

Use frequent, useful comments throughout. Comments should explain intent, dependencies, workflow, and non-obvious decisions.

## Build, Test, and Development Commands

Prefer XcodeGen for project generation and XcodeBuildMCP for build, run, and test verification when available. If XcodeBuildMCP is unavailable, use `xcodebuild`.

Expected commands after project setup:

- `xcodegen generate` regenerates the Xcode project from `project.yml`.
- `xcodebuild -scheme Mira -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build` builds the app.
- `xcodebuild -scheme Mira -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test` runs tests.
- `swift test` runs Swift Package Manager tests if package-based components exist.

Avoid committing generated build output such as `.build/`, `*.ipa`, `*.dSYM`, and Xcode user data.

## Documentation Requirements

All documentation must stay up to date. Every feature, workflow, UI, terminology, architecture, release, or behavior change must update the relevant docs in the same change.

Also keep in-app onboarding, glossary, and help data current. If a user-facing concept changes, update both code and documentation before verification is considered complete.

## Verification & Release Workflow

After every implementation change, use this workflow:

1. Regenerate project files with XcodeGen when applicable.
2. Run an XcodeBuildMCP clean build and require zero warnings.
3. Automatically and thoughtfully bump the build or revision using the project versioning workflow.
4. Update all repo documentation plus in-app onboarding, glossary, and help data.
5. Stage changes, commit with a thoughtful message, and push to the working branch.
6. Upload to TestFlight only when the change is release-gated for external validation.
7. Run quick unit tests after push/upload to catch regressions.

Run UI tests, screenshot tests, and heavier validation nightly.

## Testing Guidelines

Add unit tests for model, service, domain, and business-logic changes. Add UI tests for navigation, permissions, and user-facing workflows. Name test files after the subject under test, such as `SessionStoreTests.swift`, and name tests around behavior, such as `testLoadsRecentSessions()`.

Unit tests should be fast enough to run after each change. UI and screenshot tests belong in the nightly workflow unless the changed feature requires immediate visual verification.

## Commit & Pull Request Guidelines

Current history is minimal, so use concise, imperative commit messages such as `Add session persistence` or `Fix launch state handling`.

Pull requests should include a short summary, testing performed, linked issue or task when available, and screenshots or recordings for UI changes. Keep PRs scoped to one feature or fix.

## Agent-Specific Instructions

Preserve untracked or user-edited files unless explicitly asked to change them. Before adding tools or directories, verify the current project format and update this guide with the resulting commands and structure.

Agents must treat clean builds, zero warnings, current documentation, thoughtful versioning, and branch push readiness as part of the work, not optional follow-up.

## Private Endpoint Data

Real Tailscale IPs, machine names, API keys, endpoint snapshots, and private
model inventories must not be committed. Use ignored `LocalDev/*.local.json`
files for local smoke testing only. Public examples and tests must use fake
machines and fake hosts.
