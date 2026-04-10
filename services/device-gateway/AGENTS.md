# Device Gateway Boundary Agent Guide

## Scope
`services/device-gateway` owns provider adapters and unified command execution.

## Current State
Scaffold only. No adapter implementation exists yet.

## Planned Responsibilities
- provider-agnostic command interface
- discovery and device lookup
- adapter execution with normalized results
- provider capability mapping

## Implementation Expectations
- Keep provider code under `src/providers/<provider>/`.
- Keep shared abstractions in `src/`.
- Align command payloads with `packages/contracts/device-command.md`.
