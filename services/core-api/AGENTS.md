# Core API Boundary Agent Guide

## Scope
`services/core-api` is the Python orchestration boundary for local HTTP/WebSocket entrypoints.

## Current State
This boundary now contains runnable local voice transcription plus the first interaction endpoint for Jarvis-style responses.

## Planned Responsibilities
- Serve local API and event endpoints.
- Coordinate voice, intent parsing, and device execution.
- Return normalized execution results to iOS.
- Own app-level runtime configuration.

## Implementation Expectations
- Place runtime code under `app/`.
- Add local run/test commands to this file as soon as code is added.
- Keep request/response contracts aligned with `packages/contracts`.
- Do not return FastAPI's default `{"detail": ...}` shape for documented API errors; normalize errors to the contract-defined top-level fields.
- Centralize shared API contract logic such as error serialization instead of rebuilding the same JSON shape in multiple handlers or dependencies.
- Keep auth and app configuration centralized in `app/`.
- Keep auth failures in the same error envelope as route-level failures.
- Keep route handlers thin; speech pipeline work belongs in `services/voice`.
- Backend request traces should append JSONL events to the configured log directory, defaulting to the repo-local `.artifacts/logs/backend`.

## Local Commands
Run from `services/core-api`:

- `cp .env.template .env`
- `python3 -m venv ../../.venv`
- `../../.venv/bin/python -m pip install -e '../voice[xtts]' -e . pyright pytest`
- `bash scripts/check-python.sh`
- `bash scripts/check-python-live.sh`
- `uv sync --group dev`
- `uv run uvicorn app.main:app --reload`
- `uv run pytest`
- `docker compose up --build`

Docker defaults to host port `8010` via `JARVIS_CORE_API_HOST_PORT` while the container still listens on `8000`.
The Docker image builds `whisper.cpp` plus the configured ggml model at image build time.
When running through Docker Compose, backend trace logs are mounted back into repo-local `.artifacts/logs/backend`.
The Docker Compose runtime also mounts the XTTS cache back into repo-local `.artifacts/models/xtts` so first-run model downloads persist across container restarts.
For backend surface changes, done means both `bash scripts/check-python.sh` and a live HTTP integration run have passed.
XTTS is configured through `JARVIS_TTS_*` settings, and the Docker integration path now defaults `JARVIS_TTS_PROVIDER` to `xtts` unless explicitly overridden.
