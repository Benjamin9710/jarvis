# LIFX Provider Agent Guide

## Scope
LIFX adapter boundary for local LAN-first device control.

## Planned Capabilities
- local discovery
- power control
- brightness control
- color control
- optional cloud fallback

## Implementation Guidance
- Keep transport layer isolated from command mapping.
- Normalize LIFX-specific response fields into shared gateway result types.
- Add fixture-driven tests for command translation behavior.
