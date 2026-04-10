# Providers Agent Guide

## Scope
Each provider directory owns its adapter, mapping, and transport concerns.

## Provider Structure
- `lifx/` for LIFX discovery and execution.
- `tuya/` for Tuya/Mirabella mapping and execution.

## Implementation Rules
- Do not couple one provider adapter to another provider's internals.
- Normalize provider responses before returning to shared gateway code.
- Keep provider-specific credentials and secrets out of source control.
