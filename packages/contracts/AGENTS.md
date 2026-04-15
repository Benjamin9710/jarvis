# Contracts Package Agent Guide

## Scope
`packages/contracts` defines cross-boundary payload shapes and examples.

## Current Artifacts
- `command-intent.md`
- `device-command.md`
- `voice-interaction.md`
- `voice-transcription.md`

## Editing Guidance
- Treat docs here as source of truth for request and execution schemas.
- When changing a contract, update all impacted boundaries in the same change.
- Prefer explicit examples for edge cases and failure payloads.

## Consistency Checks
- Keep naming and field semantics stable across iOS, core API, and gateway boundaries.
- Call out breaking changes directly in contract docs.
