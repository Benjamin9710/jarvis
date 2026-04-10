# Core API Boundary Agent Guide

## Scope
`services/core-api` is the Python orchestration boundary for local HTTP/WebSocket entrypoints.

## Current State
This boundary is scaffolded only. No runnable Python modules exist yet.

## Planned Responsibilities
- Serve local API and event endpoints.
- Coordinate voice, intent parsing, and device execution.
- Return normalized execution results to iOS.
- Own app-level runtime configuration.

## Implementation Expectations
- Place runtime code under `app/`.
- Add local run/test commands to this file as soon as code is added.
- Keep request/response contracts aligned with `packages/contracts`.
