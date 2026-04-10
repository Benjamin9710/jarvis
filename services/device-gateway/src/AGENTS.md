# Device Gateway Source Agent Guide

## Scope
Shared abstractions and routing internals for provider adapters.

## Planned Areas
- provider registry
- adapter interfaces
- command normalization
- execution helpers

## Design Guidance
- Keep provider-specific branching out of shared interfaces.
- Keep error/result types stable and contract-driven.
- Add deterministic unit tests for routing and normalization logic.
