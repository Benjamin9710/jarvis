#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
SERVICE_DIR="$ROOT_DIR/services/core-api"
FIXTURE_PATH="$ROOT_DIR/services/voice/tests/fixtures/jfk.wav"
INVALID_PATH="$ROOT_DIR/services/core-api/app/auth.py"

if [[ ! -f "$FIXTURE_PATH" ]]; then
  echo "Missing speech fixture at $FIXTURE_PATH"
  exit 1
fi

load_env_file() {
  local env_file="$1"
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
}

preserve_env_overrides() {
  local variable_name
  for variable_name in \
    JARVIS_CORE_API_HOST_PORT \
    JARVIS_API_BEARER_TOKEN \
    JARVIS_STT_PROVIDER \
    JARVIS_WHISPER_CPP_VERSION \
    JARVIS_WHISPER_CPP_MODEL \
    JARVIS_WHISPER_CPP_BINARY_PATH \
    JARVIS_WHISPER_CPP_MODEL_PATH \
    JARVIS_WHISPER_CPP_THREADS \
    JARVIS_TRANSCRIPTION_TIMEOUT_SECONDS \
    JARVIS_TEMP_AUDIO_DIR \
    JARVIS_BACKEND_LOG_DIR; do
    if [[ -n "${!variable_name+x}" ]]; then
      export "PRESERVED_${variable_name}=${!variable_name}"
    fi
  done
}

restore_env_overrides() {
  local variable_name
  local preserved_name
  for variable_name in \
    JARVIS_CORE_API_HOST_PORT \
    JARVIS_API_BEARER_TOKEN \
    JARVIS_STT_PROVIDER \
    JARVIS_WHISPER_CPP_VERSION \
    JARVIS_WHISPER_CPP_MODEL \
    JARVIS_WHISPER_CPP_BINARY_PATH \
    JARVIS_WHISPER_CPP_MODEL_PATH \
    JARVIS_WHISPER_CPP_THREADS \
    JARVIS_TRANSCRIPTION_TIMEOUT_SECONDS \
    JARVIS_TEMP_AUDIO_DIR \
    JARVIS_BACKEND_LOG_DIR; do
    preserved_name="PRESERVED_${variable_name}"
    if [[ -n "${!preserved_name+x}" ]]; then
      export "${variable_name}=${!preserved_name}"
    fi
  done
}

preserve_env_overrides
load_env_file "$SERVICE_DIR/.env.template"
load_env_file "$SERVICE_DIR/.env"
restore_env_overrides

HOST_PORT="${JARVIS_CORE_API_HOST_PORT:-8010}"
API_BASE_URL="http://127.0.0.1:${HOST_PORT}"
TOKEN="${JARVIS_API_BEARER_TOKEN:-change-me}"
BACKEND_LOG_DIR="${JARVIS_BACKEND_LOG_DIR:-$ROOT_DIR/.artifacts/logs/backend}"
if [[ "$BACKEND_LOG_DIR" != /* ]]; then
  BACKEND_LOG_DIR="$SERVICE_DIR/$BACKEND_LOG_DIR"
fi
BACKEND_LOG_PATH="${BACKEND_LOG_DIR}/core-api.jsonl"
DOCKER_BACKEND_LOG_DIR="/var/log/jarvis/backend"

cleanup() {
  cd "$SERVICE_DIR"
  docker compose down --remove-orphans >/dev/null
}

trap cleanup EXIT

rm -rf "$BACKEND_LOG_DIR"
mkdir -p "$BACKEND_LOG_DIR"

cd "$SERVICE_DIR"
JARVIS_BACKEND_LOG_DIR="$DOCKER_BACKEND_LOG_DIR" docker compose up --build -d

for _attempt in $(seq 1 60); do
  status_code="$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE_URL/healthz" || true)"
  if [[ "$status_code" == "200" ]]; then
    break
  fi
  sleep 1
done

if [[ "${status_code:-000}" != "200" ]]; then
  echo "Core API did not become healthy on $API_BASE_URL"
  docker compose logs --tail=200
  exit 1
fi

success_body="$(curl -sS -X POST "$API_BASE_URL/v1/voice/transcriptions" \
  -H "Authorization: Bearer $TOKEN" \
  -F "audio_file=@${FIXTURE_PATH};type=audio/wav" \
  -F "client_request_id=live-http-check" \
  -F "device_name=docker-integration")"

python3 -c '
import json
import sys

payload = json.loads(sys.argv[1])
normalized = payload["normalized_text"].lower()
for token in ("ask", "country"):
    if token not in normalized:
        raise SystemExit(f"missing token in transcript: {token}; payload={payload}")
if payload["request_id"] != "live-http-check":
    raise SystemExit(f"unexpected request_id: {payload}")
' "$success_body"

python3 -c '
import json
import pathlib
import sys

log_path = pathlib.Path(sys.argv[1])
request_id = sys.argv[2]
if not log_path.exists():
    raise SystemExit(f"backend log file not created: {log_path}")

entries = [json.loads(line) for line in log_path.read_text(encoding="utf-8").splitlines() if line.strip()]
matching = [entry for entry in entries if entry.get("request_id") == request_id]
if not matching:
    raise SystemExit(f"request_id not found in backend logs: {request_id}")
if not any(entry.get("event_name") == "http.request" for entry in matching):
    raise SystemExit(f"http.request event missing in backend logs: {matching}")
' "$BACKEND_LOG_PATH" "live-http-check"

unauthorized_response="$(curl -sS -w $'\n%{http_code}' -X POST "$API_BASE_URL/v1/voice/transcriptions" \
  -F "audio_file=@${FIXTURE_PATH};type=audio/wav")"
unauthorized_status="$(printf '%s\n' "$unauthorized_response" | tail -n 1)"
unauthorized_body="$(printf '%s\n' "$unauthorized_response" | sed '$d')"

if [[ "$unauthorized_status" != "401" ]]; then
  echo "Expected 401 for missing auth, got $unauthorized_status"
  echo "$unauthorized_body"
  exit 1
fi

python3 -c '
import json
import sys

payload = json.loads(sys.argv[1])
if payload != {"error_code": "unauthorized", "message": "Missing bearer token."}:
    raise SystemExit(f"unexpected unauthorized payload: {payload}")
' "$unauthorized_body"

invalid_response="$(curl -sS -w $'\n%{http_code}' -X POST "$API_BASE_URL/v1/voice/transcriptions" \
  -H "Authorization: Bearer $TOKEN" \
  -F "audio_file=@${INVALID_PATH};type=text/plain")"
invalid_status="$(printf '%s\n' "$invalid_response" | tail -n 1)"
invalid_body="$(printf '%s\n' "$invalid_response" | sed '$d')"

if [[ "$invalid_status" != "415" ]]; then
  echo "Expected 415 for invalid media, got $invalid_status"
  echo "$invalid_body"
  exit 1
fi

python3 -c '
import json
import sys

payload = json.loads(sys.argv[1])
if payload["error_code"] != "unsupported_audio_format":
    raise SystemExit(f"unexpected invalid-media payload: {payload}")
if payload["message"] != "v1 only accepts WAV uploads.":
    raise SystemExit(f"unexpected invalid-media payload: {payload}")
if not payload.get("request_id"):
    raise SystemExit(f"missing request_id in invalid-media payload: {payload}")
' "$invalid_body"

echo "Live HTTP integration checks passed."
