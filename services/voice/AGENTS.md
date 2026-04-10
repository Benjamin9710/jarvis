# Voice Service Boundary Agent Guide

## Scope
`services/voice` will own speech pipeline processing and audio session workflows.

## Current State
Scaffold only. No runnable modules yet.

## Planned Responsibilities
- voice session lifecycle
- speech-to-text adapter integration
- transcript normalization
- text-to-speech synthesis response payloads

## Implementation Expectations
- Keep concrete modules under `src/`.
- Isolate vendor-specific SDK calls behind adapters.
- Add tests with each first implementation slice.
