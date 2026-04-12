# Voice Service Boundary Agent Guide

## Scope
`services/voice` will own speech pipeline processing and audio session workflows.

## Current State
This boundary now contains the first speech-to-text models, normalization logic, and adapter scaffolding.

## Planned Responsibilities
- voice session lifecycle
- speech-to-text adapter integration
- transcript normalization
- text-to-speech synthesis response payloads

## Implementation Expectations
- Keep concrete modules under `src/`.
- Isolate vendor-specific SDK calls behind adapters.
- Add tests with each first implementation slice.
- Treat uploaded audio as ephemeral and delete temp files on success and failure.
- Keep offline-first STT behavior portable across Apple Silicon and Linux.
- Run static checks with `../../.venv/bin/pyright` from repo root after Python changes.
- When changing a real STT adapter, run at least one non-fake transcription path against the actual runtime before handoff.
