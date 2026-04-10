# iOS Script Agent Guide

## Purpose
These scripts are the supported way to build and test the iOS app in Codex and local terminals.

## Current Scripts
- `resolve-simulator-device.sh` selects a simulator device if none is provided.
- `preflight-ios-testing.sh` validates `xcodebuild`, `xcrun`, `simctl`, and device availability.
- `build-simulator.sh` builds the app for simulator.
- `test-ui-interactions.sh` runs only `JarvisIOSUITests` and emits an `.xcresult`.
- `test-simulator.sh` runs full tests and emits an `.xcresult`.

## Editing Rules
- Keep scripts `bash` + `set -euo pipefail`.
- Preserve optional explicit device override via first argument.
- Keep CLT fallback behavior using `DEVELOPER_DIR` if full Xcode exists.
- Keep output stable and CI-friendly (single-line status messages where possible).
