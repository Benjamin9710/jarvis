# JarvisIOS App Agent Guide

## Architecture Map
- `App/` app entrypoint and scene bootstrap.
- `Support/` environment wiring and scenario selection.
- `Features/MissionControl/` screen/view-model for capture flow.
- `Voice/` microphone permission, capture service, and models.
- `UI/` theme and shared HUD components.

## Behavior Invariants
- Mission control must keep microphone capture separate from backend upload/transcription concerns.
- `VoiceCaptureViewModel` is the state authority for user-facing capture states.
- Real microphone access stays isolated in `VoiceCaptureService`.
- Real HTTP upload stays isolated in the backend interaction client.
- Response playback stays isolated behind `VoiceResponsePlaybackServiceProtocol`.
- UI tests must work via `MockVoiceCaptureService` scenario injection.

## UI Testability
- Keep stable accessibility identifiers for tappable controls.
- Keep headline/state text deterministic per capture state.
- Supported test scenarios are `ready`, `permission-needed`, `recording`, `error`.
- Backend UI test behavior is selected with `JARVIS_INTERACTION_SCENARIO`.

## Change Guidance
- If adding a new capture state, update:
  - models in `Voice/`
  - view-model labels/actions
  - unit tests
  - UI launch scenarios and assertions
- If changing the upload/transcription path, update mock backend scenarios and transcript-panel assertions alongside the view-model.
- If changing interaction responses, update summary text, transcript text, replay affordances, and UI-test scenarios together.
- Keep styling centralized in `UI/JarvisTheme.swift` and HUD components.
