#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
VENV_PYTHON="$ROOT_DIR/.venv/bin/python"
VENV_PYRIGHT="$ROOT_DIR/.venv/bin/pyright"

if [[ ! -x "$VENV_PYTHON" ]]; then
  echo "Missing virtualenv at $ROOT_DIR/.venv"
  echo "Run: python3 -m venv .venv"
  echo "Then: .venv/bin/python -m pip install -e services/voice -e services/core-api pyright pytest"
  exit 1
fi

if [[ ! -x "$VENV_PYRIGHT" ]]; then
  echo "Missing pyright in virtualenv."
  echo "Run: .venv/bin/python -m pip install pyright"
  exit 1
fi

cd "$ROOT_DIR"

echo "Running pyright..."
"$VENV_PYRIGHT"

echo "Running voice tests..."
PYTHONPATH=services/voice/src "$VENV_PYTHON" -m pytest services/voice/tests

echo "Running core-api tests..."
PYTHONPATH=services/core-api:services/voice/src "$VENV_PYTHON" -m pytest services/core-api/tests

echo "Running live HTTP integration checks..."
bash services/core-api/scripts/check-python-live.sh
