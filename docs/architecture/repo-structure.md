# Repo Structure

The repository is organized as a small monorepo:

```text
apps/
  ios/
services/
  core-api/
    app/
  voice/
    src/
  device-gateway/
    src/
      providers/
        lifx/
        tuya/
packages/
  contracts/
docs/
  architecture/
  setup/
```

This structure mirrors the boundaries defined in `docs/jarvis-v1-foundation.md` and keeps the first vertical slice easy to reason about:

- client app in `apps`
- backend execution surfaces in `services`
- shared contracts in `packages`
- planning and operational docs in `docs`
