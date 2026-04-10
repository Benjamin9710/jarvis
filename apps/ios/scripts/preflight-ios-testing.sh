#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_NAME="$("${ROOT_DIR}/scripts/resolve-simulator-device.sh" "${1:-}")"

# Fall back to an explicit Xcode install when xcode-select still points at CLT.
if ! xcodebuild -version >/dev/null 2>&1 && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild is unavailable. Install full Xcode and select it with:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "ERROR: xcrun is unavailable. Install full Xcode command-line tools." >&2
  exit 1
fi

if ! xcrun simctl help >/dev/null 2>&1; then
  echo "ERROR: simctl is unavailable from the active developer directory." >&2
  echo "Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

if ! xcrun simctl list devices available | rg -q "${DEVICE_NAME}"; then
  echo "ERROR: Simulator device '${DEVICE_NAME}' is not available." >&2
  echo "Available simulator devices:" >&2
  xcrun simctl list devices available | sed 's/^/  /'
  exit 1
fi

echo "Preflight passed for simulator device '${DEVICE_NAME}'."
