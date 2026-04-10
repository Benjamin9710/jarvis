# Tuya Provider Agent Guide

## Scope
Tuya and Mirabella adapter boundary for local command execution and mapping.

## Planned Capabilities
- local device metadata handling
- LAN command execution
- Mirabella compatibility mapping
- optional cloud fallback hooks

## Implementation Guidance
- Keep Mirabella compatibility logic explicit and testable.
- Separate protocol transport from command-shape mapping.
- Normalize Tuya-specific status/output into shared gateway result types.
