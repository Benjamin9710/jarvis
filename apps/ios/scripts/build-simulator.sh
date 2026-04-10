#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_NAME="$("${ROOT_DIR}/scripts/resolve-simulator-device.sh" "${1:-}")"

# Fall back to an explicit Xcode install when xcode-select still points at CLT.
if ! xcodebuild -version >/dev/null 2>&1 && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

xcodebuild \
  -project "${ROOT_DIR}/JarvisIOS.xcodeproj" \
  -scheme JarvisIOS \
  -destination "platform=iOS Simulator,name=${DEVICE_NAME}" \
  build
