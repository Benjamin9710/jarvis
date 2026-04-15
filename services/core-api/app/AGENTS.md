# Core API App Package Agent Guide

## Scope
This package should contain FastAPI app modules and orchestration wiring.

## Planned Areas
- route handlers
- request/response models
- dependency wiring
- startup and configuration
- auth enforcement
- error normalization
- local request telemetry

## Test Guidance
Add pytest coverage in this boundary for:
- route behavior
- orchestration flow
- error normalization
- auth enforcement
- dependency overrides for fake speech adapters

## API Invariants
- When a route documents `ErrorResponse`, all failure paths for that route, including auth/dependency failures, must return the same top-level JSON shape.
- Do not raise `HTTPException(detail=...)` for contract-bound API errors unless the serialized response still matches the documented schema.
- Use a shared app-level helper for contract-bound error responses; do not hand-build the same error JSON in multiple modules.
- Authorization parsing must follow HTTP semantics, including case-insensitive auth scheme handling.
- Add or update tests for both success and failure contract shape whenever auth or dependency behavior changes.
- Keep backend trace logs metadata-only by default; do not write raw audio bytes or transcript text into the local JSONL log.
- Treat `/v1/voice/interactions` unsupported commands as successful contract responses, not route errors.
- If TTS fails inside an interaction response, return text fields with `tts_status = failed` and null audio fields instead of raising a route error.
