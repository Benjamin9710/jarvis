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

Python quality workflow:

- `bash services/core-api/scripts/check-python.sh`

## Coding Style & Naming Conventions
Follow planned stack and boundary naming:

- Python with 4 spaces in backend services.
- Swift/SwiftUI conventions for `apps/ios` are defined in `apps/ios/AGENTS.md`.
- Markdown docs with concise operational prose.
- Boundary-driven names such as `core-api`, `device-gateway`, `DeviceCommand`.
- Provider-specific logic under `services/device-gateway/src/providers/<provider>/`.

## DRY Rules
- Treat duplicated business logic, contract shaping, and validation rules as defects; extract a shared helper/module instead of copying behavior.
- When the same logic appears in a second place, stop and consolidate it in the nearest shared boundary before adding a third copy.
- Prefer one authoritative implementation for each contract or invariant, and have callers depend on that implementation rather than rebuilding payloads ad hoc.
- When introducing a shared helper, add or update tests that exercise the shared path so future changes cannot silently diverge.

## Testing Guidelines
Add tests with every implementation change:

- Keep tests close to the code they validate.
- Name tests after behavior (`test_turn_on_lifx_bulb`, `VoiceCaptureViewModelTests`).
- For `apps/ios`, simulator automation is part of done:
  - run preflight first
  - run full suite for behavior changes
  - run UI-only suite for interaction checks
- Keep microphone and capture flows mockable so tests do not require real hardware.

## Quality Gates For New Stacks
When introducing a new language, framework, or runtime, do not ship code until quality gates are defined and runnable locally.

Required setup in the same change that introduces the new stack:

- Add formatting/linting/static analysis tools appropriate to that stack.
- Add automated tests (at least unit tests; include integration tests when boundary behavior is involved).
- Add deterministic commands/scripts to run checks locally.
- Document commands and expectations in the nearest boundary `AGENTS.md`.
- Update root `AGENTS.md` if new cross-repo commands or standards are added.

Required execution before handoff:

- Run lint/format/type-check/test commands relevant to changed files.
- Run real integration coverage for any changed app/API boundary, not just mocks or in-process unit paths.
- For backend HTTP changes, run at least one live request path against the service entrypoint that the real client will use.
- For adapter/provider changes, run at least one non-fake integration path against the actual runtime binary or SDK before handoff.
- If a required tool cannot run in the environment, state exactly what was not run and why.
- Do not assume correctness from compilation or code inspection alone.

Minimum bar by category:

- Compiled or interpreted app code: formatter/linter + tests.
- API/service code: linter/type-check + unit tests + at least one boundary/integration path.
- Containerized API/service code: the above plus at least one dockerized smoke/integration run when Docker is part of the supported runtime.
- Shared contracts/schemas: schema validation or contract-focused tests/examples plus consumer impact notes.

## Commit & Pull Request Guidelines
Use focused commits with imperative subjects, for example:

- `Add simulator preflight checks`
- `Implement capture state reducer`

PRs should summarize changed boundary, linked planning doc/issue, and include screenshots for iOS UI changes when relevant. Update local `AGENTS.md` guidance when workflows or architecture expectations change.

## Security & Configuration Tips
Do not commit secrets, local keys, or `.env` files. Extend `.gitignore` when new tools generate local artifacts.
