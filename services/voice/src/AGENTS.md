# Voice Source Agent Guide

## Scope
Internal modules for the voice pipeline should live here.

## Planned Module Areas
- session management
- STT adapters
- transcript normalization
- TTS adapters

## Current Implementation Notes
- `jarvis_voice.service` owns temp-file lifecycle and duration extraction.
- `jarvis_voice.adapters` exposes the provider-agnostic STT interface plus concrete adapters.
- `jarvis_voice.normalization` must stay conservative and should not infer user intent.
- `jarvis_voice.responses` owns deterministic Jarvis text composition.
- `jarvis_voice.tts` owns synthesized WAV generation and temp-file cleanup for TTS responses.

## Design Guidance
- Keep interfaces provider-agnostic.
- Keep transcript/event models aligned with `packages/contracts`.
- Add behavior-focused tests next to implementation modules.
