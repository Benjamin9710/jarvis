# Voice Source Agent Guide

## Scope
Internal modules for the voice pipeline should live here.

## Planned Module Areas
- session management
- STT adapters
- transcript normalization
- TTS adapters

## Design Guidance
- Keep interfaces provider-agnostic.
- Keep transcript/event models aligned with `packages/contracts`.
- Add behavior-focused tests next to implementation modules.
