#!/usr/bin/env bash
set -euo pipefail

PREFERRED_DEVICE="${1:-}"

# Fall back to an explicit Xcode install when xcode-select still points at CLT.
if ! xcodebuild -version >/dev/null 2>&1 && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

if [[ -n "${PREFERRED_DEVICE}" ]]; then
  echo "${PREFERRED_DEVICE}"
  exit 0
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "ERROR: xcrun is unavailable. Install full Xcode command-line tools." >&2
  exit 1
fi

if ! xcrun simctl help >/dev/null 2>&1; then
  echo "ERROR: simctl is unavailable from the active developer directory." >&2
  exit 1
fi

RESOLVED_DEVICE="$(
  xcrun simctl list devices available \
    | sed -En 's/^[[:space:]]*(iPhone[^()]+)[[:space:]]+\([0-9A-F-]+\).*/\1/p' \
    | sed -E 's/[[:space:]]+$//' \
    | head -n 1
)"

if [[ -z "${RESOLVED_DEVICE}" ]]; then
  echo "ERROR: No available iPhone simulator device was found." >&2
  exit 1
fi

echo "${RESOLVED_DEVICE}"
