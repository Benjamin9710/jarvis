# Jarvis v1 Foundation Plan

## Summary
- Build `Jarvis` as a **local-first home automation assistant** with an **iPhone-first client** and an **always-on Python backend** running on your existing Mac on the local network.
- Optimize v1 for **reliable voice-to-light control** while keeping the core architecture extensible for other device classes later.
- Use **deterministic intent parsing** for known commands in v1; keep a clean extension point for a local or cloud LLM router later when ambiguity handling becomes worth the complexity.
- Treat the first deliverable as a working vertical slice: **capture voice on iPhone → send audio to local backend → transcribe → parse → route to device adapter → execute light command → return spoken/text confirmation**.

## Key Changes / Architecture
- **Languages**
  - **Backend:** `Python` for audio/STT orchestration, intent parsing, device adapters, and API server.
  - **iPhone app:** `Swift` + `SwiftUI` for microphone capture, push-to-talk / always-listen modes, device UI, and response playback.
  - **Optional later admin UI:** `TypeScript` web app only if a browser control panel becomes necessary; do not make it part of the first implementation path.
- **Core backend subsystems**
  - `api`: local HTTP/WebSocket API for the iPhone app.
  - `voice`: session handling, audio ingestion, STT, command normalization, TTS response generation.
  - `intent`: structured parser for commands like power, brightness, color, room, scene.
  - `devices`: provider-based adapter layer (`lifx`, `tuya/mirabella`) behind one common command interface.
  - `automation`: command routing, device lookup, scene execution, fallback/error policy.
  - `config`: device registry, room mappings, secrets, and environment-specific settings.
- **Public interfaces / types**
  - Define a canonical `CommandIntent` shape with fields like `action`, `target_type`, `target_name`, `room`, `value`, `color`, `brightness`, `confidence`, `raw_text`.
  - Define a provider-agnostic `DeviceCommand` contract so `LIFX` and `Mirabella/Tuya` adapters expose the same operations: `turn_on`, `turn_off`, `set_brightness`, `set_color`, `get_state`.
  - Expose backend endpoints/events for:
    - audio submission / streaming from iPhone
    - recognized transcript + parsed intent
    - command execution result
    - device list / room list / state sync
- **Recommended repo structure**
  - `apps/ios` — SwiftUI iPhone client.
  - `services/core-api` — Python API server and orchestration entrypoint.
  - `services/voice` — STT/TTS/session pipeline.
  - `services/device-gateway` — provider adapters and device abstraction.
  - `packages/contracts` — shared API schemas / example payload docs.
  - `docs` — architecture notes, setup, device onboarding, roadmap.
- **Technology choices for v1**
  - Backend API: `FastAPI`.
  - STT: local backend STT on the Mac; start with an offline-first engine suited to command recognition.
  - TTS: local backend TTS with simple response playback to the phone.
  - Device control: direct LAN integrations first (`LIFX` LAN, `Tuya/Mirabella` local where feasible), with cloud fallback designed but not required for the first vertical slice.
- **Product behavior**
  - The iPhone app is the primary microphone and response surface in v1.
  - V1 command handling is narrow and deterministic: lights, rooms, scenes, brightness, colors, and status queries.
  - Unknown or unsupported requests return a clear failure response and are logged for future capability planning.
  - Architecture remains extensible so non-light devices can be added as new provider modules and intent targets without rewriting the command pipeline.

## Test Plan
- **Voice path**
  - Short commands: “turn on kitchen lights”, “set bedroom lights to warm white”, “dim lounge to 30 percent”.
  - Entity extraction: room names, colors, brightness percentages, plural/singular light targets.
  - Failure handling: low-confidence transcript, unsupported command, no matching device, duplicate room names.
- **Device path**
  - LIFX local discovery and command execution.
  - Mirabella/Tuya local control with stored device metadata and key handling.
  - Timeout/offline behavior, partial failures, and command retries where safe.
- **Client/server path**
  - Audio upload/streaming from iPhone to backend over local network.
  - Response round-trip latency target suitable for command use.
  - Device state sync and manual control UI behavior.
- **Acceptance criteria**
  - From the iPhone, you can issue at least core light commands by voice and get a reliable spoken/text confirmation.
  - Backend routes commands through one unified device abstraction instead of provider-specific ad hoc logic.
  - The repo structure supports adding a new device provider without changing the iPhone app contract.

## Assumptions and Defaults
- Local backend host is your existing Mac on the home network for the first implementation.
- The initial frontend is **iPhone-only**; Android, dedicated room nodes, and browser admin are deferred.
- The first milestone ships **lights only**, but internal abstractions are designed for future devices.
- The first parser is **structured, deterministic, and non-LLM-driven**; a local/cloud LLM router is a later enhancement layer, not a v1 dependency.
- The first planning document to write in-repo should be `docs/jarvis-v1-foundation.md`, and it should capture architecture, language choices, repo layout, command model, and milestone sequence.
