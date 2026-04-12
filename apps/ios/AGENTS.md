# iOS Boundary Agent Guide

## Scope
`apps/ios` owns the iPhone client. This boundary currently contains production code and tests.

## Key Paths
- `JarvisIOS/` app source.
- `JarvisIOSTests/` unit tests.
- `JarvisIOSUITests/` simulator UI tests.
- `scripts/` deterministic local build and test commands.
- `.artifacts/test-results/` generated `.xcresult` bundles.

## Local Commands
Run from `apps/ios`:

- `bash scripts/preflight-ios-testing.sh`
- `bash scripts/build-simulator.sh`
- `bash scripts/test-simulator.sh`
- `bash scripts/test-ui-interactions.sh`
- `swift-format format --in-place --recursive JarvisIOS JarvisIOSTests JarvisIOSUITests`
- `swiftlint lint --strict`

Device argument is optional. If omitted, scripts auto-pick the first available iPhone simulator.

## Implementation Rules
- Keep capture logic mockable through `VoiceCaptureServiceProtocol`.
- Keep UI deterministic for tests via launch args and `JARVIS_CAPTURE_SCENARIO`.
- Keep backend upload/transcription behavior behind a separate client from the microphone capture service.
- Source backend URL/token/device diagnostics centrally from `AppEnvironment`.
- Preserve Jarvis-style mission-control visual language unless explicitly redesigning.
- For any changed `.swift` files, run `swift-format` before running tests or handing off changes.
- Keep `swiftlint lint --strict` passing for this boundary.

## Testing Rules
- For capture behavior changes: update unit tests and UI tests.
- For backend transcription UI changes: cover success and failure using mock backend scenarios.
- For visual/state interaction changes: run `test-ui-interactions.sh`.
- For service/view-model changes: run `test-simulator.sh`.
- When Xcode/simulator is unavailable, explicitly state the limitation.
