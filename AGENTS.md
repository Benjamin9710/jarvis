# Repository Guidelines

## Project Structure & Module Organization
Jarvis is a local-first home automation monorepo. Keep changes inside existing boundaries:

- `apps/ios` for the SwiftUI iPhone client (implemented and testable now).
- `services/core-api` for Python API orchestration (scaffold boundary).
- `services/voice` for the speech pipeline (scaffold boundary).
- `services/device-gateway` for provider adapters under `src/providers/` (scaffold boundary).
- `packages/contracts` for shared payload schemas and examples.
- `docs` for architecture, setup, and planning notes.

Add code inside the nearest boundary instead of creating new top-level buckets.

## Agent Context Files
This repository uses `AGENTS.md` (not `README.md`) for local build and implementation guidance intended for Codex and other coding agents.

- Keep a boundary-local `AGENTS.md` in each active app/service folder.
- When behavior changes, update the nearest `AGENTS.md` in the same commit.
- On every change, check all relevant `AGENTS.md` files and update or add rules when guidance is missing or outdated.
- Prefer concise, actionable instructions (commands, invariants, testing expectations).

## Build, Test, and Development Commands
Use lightweight inspection commands for repo navigation:

- `rg --files`
- `rg "CommandIntent|DeviceCommand|VoiceCapture" packages docs services apps`
- `git status`

Current runnable workflows exist in `apps/ios`:

- `bash apps/ios/scripts/preflight-ios-testing.sh`
- `bash apps/ios/scripts/build-simulator.sh`
- `bash apps/ios/scripts/test-simulator.sh`
- `bash apps/ios/scripts/test-ui-interactions.sh`

## Coding Style & Naming Conventions
Follow planned stack and boundary naming:

- Python with 4 spaces in backend services.
- Swift/SwiftUI conventions for `apps/ios` are defined in `apps/ios/AGENTS.md`.
- Markdown docs with concise operational prose.
- Boundary-driven names such as `core-api`, `device-gateway`, `DeviceCommand`.
- Provider-specific logic under `services/device-gateway/src/providers/<provider>/`.

## Testing Guidelines
Add tests with every implementation change:

- Keep tests close to the code they validate.
- Name tests after behavior (`test_turn_on_lifx_bulb`, `VoiceCaptureViewModelTests`).
- For `apps/ios`, simulator automation is part of done:
  - run preflight first
  - run full suite for behavior changes
  - run UI-only suite for interaction checks
- Keep microphone and capture flows mockable so tests do not require real hardware.

## Commit & Pull Request Guidelines
Use focused commits with imperative subjects, for example:

- `Add simulator preflight checks`
- `Implement capture state reducer`

PRs should summarize changed boundary, linked planning doc/issue, and include screenshots for iOS UI changes when relevant. Update local `AGENTS.md` guidance when workflows or architecture expectations change.

## Security & Configuration Tips
Do not commit secrets, local keys, or `.env` files. Extend `.gitignore` when new tools generate local artifacts.
