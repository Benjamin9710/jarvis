# JarvisIOS App Agent Guide

## Architecture Map
- `App/` app entrypoint and scene bootstrap.
- `Support/` environment wiring and scenario selection.
- `Features/MissionControl/` screen/view-model for capture flow.
- `Voice/` microphone permission, capture service, and models.
- `UI/` theme and shared HUD components.

## Behavior Invariants
- Mission control must reach capture start/stop flows without backend dependencies.
- `VoiceCaptureViewModel` is the state authority for user-facing capture states.
- Real microphone access stays isolated in `VoiceCaptureService`.
- UI tests must work via `MockVoiceCaptureService` scenario injection.

## UI Testability
- Keep stable accessibility identifiers for tappable controls.
- Keep headline/state text deterministic per capture state.
- Supported test scenarios are `ready`, `permission-needed`, `recording`, `error`.

## Change Guidance
- If adding a new capture state, update:
  - models in `Voice/`
  - view-model labels/actions
  - unit tests
  - UI launch scenarios and assertions
- Keep styling centralized in `UI/JarvisTheme.swift` and HUD components.
