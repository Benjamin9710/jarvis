#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_NAME="$("${ROOT_DIR}/scripts/resolve-simulator-device.sh" "${1:-}")"
ARTIFACTS_DIR="${ROOT_DIR}/.artifacts/test-results"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
RESULT_BUNDLE="${ARTIFACTS_DIR}/JarvisIOS-Full-${TIMESTAMP}.xcresult"

# Fall back to an explicit Xcode install when xcode-select still points at CLT.
if ! xcodebuild -version >/dev/null 2>&1 && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

"${ROOT_DIR}/scripts/preflight-ios-testing.sh" "${DEVICE_NAME}"

mkdir -p "${ARTIFACTS_DIR}"

UDID="$(xcrun simctl list devices available | sed -En "s/.*${DEVICE_NAME} \\(([0-9A-F-]+)\\) .*/\\1/p" | head -n 1)"
if [[ -z "${UDID}" ]]; then
  echo "ERROR: Could not resolve simulator UDID for '${DEVICE_NAME}'." >&2
  exit 1
fi

xcodebuild \
  -project "${ROOT_DIR}/JarvisIOS.xcodeproj" \
  -scheme JarvisIOS \
  -destination "id=${UDID}" \
  -resultBundlePath "${RESULT_BUNDLE}" \
  test

echo "Full simulator test result bundle: ${RESULT_BUNDLE}"
