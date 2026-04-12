from pathlib import Path
import json

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app


FIXTURE_PATH = Path(__file__).resolve().parents[2] / "voice" / "tests" / "fixtures" / "silence-1s.wav"


def test_voice_transcription_returns_normalized_result() -> None:
    client = _make_client()

    with FIXTURE_PATH.open("rb") as fixture:
        response = client.post(
            "/v1/voice/transcriptions",
            headers={"Authorization": "Bearer test-token"},
            files={"audio_file": ("silence-1s.wav", fixture, "audio/wav")},
            data={"client_request_id": "test-request", "device_name": "CI iPhone"},
        )

    assert response.status_code == 200
    assert response.json() == {
        "request_id": "test-request",
        "transcript_text": "Turn on the kitchen lights",
        "normalized_text": "turn on the kitchen lights",
        "language": "en",
        "duration_ms": 1000,
        "provider": "fake-stt",
        "confidence": None,
    }


def test_voice_transcription_requires_bearer_token() -> None:
    client = _make_client()

    with FIXTURE_PATH.open("rb") as fixture:
        response = client.post(
            "/v1/voice/transcriptions",
            files={"audio_file": ("silence-1s.wav", fixture, "audio/wav")},
        )

    assert response.status_code == 401
    assert response.json() == {
        "error_code": "unauthorized",
        "message": "Missing bearer token.",
    }


def test_voice_transcription_accepts_lowercase_bearer_scheme() -> None:
    client = _make_client()

    with FIXTURE_PATH.open("rb") as fixture:
        response = client.post(
            "/v1/voice/transcriptions",
            headers={"Authorization": "bearer test-token"},
            files={"audio_file": ("silence-1s.wav", fixture, "audio/wav")},
            data={"client_request_id": "test-request"},
        )

    assert response.status_code == 200
    assert response.json()["request_id"] == "test-request"


def test_voice_transcription_rejects_non_wav_upload() -> None:
    client = _make_client()

    response = client.post(
        "/v1/voice/transcriptions",
        headers={"Authorization": "Bearer test-token"},
        files={"audio_file": ("notes.txt", b"hello", "text/plain")},
    )

    assert response.status_code == 415
    assert response.json() == {
        "request_id": response.json()["request_id"],
        "error_code": "unsupported_audio_format",
        "message": "v1 only accepts WAV uploads.",
    }


def test_voice_transcription_writes_correlated_trace_events(tmp_path: Path) -> None:
    client = _make_client(tmp_path=tmp_path)

    with FIXTURE_PATH.open("rb") as fixture:
        response = client.post(
            "/v1/voice/transcriptions",
            headers={"Authorization": "Bearer test-token"},
            files={"audio_file": ("silence-1s.wav", fixture, "audio/wav")},
            data={"client_request_id": "test-request", "device_name": "CI iPhone"},
        )

    assert response.status_code == 200

    entries = _read_log_entries(tmp_path / "core-api.jsonl")
    matching = [entry for entry in entries if entry["request_id"] == "test-request"]

    assert [entry["event_name"] for entry in matching] == [
        "auth.verify_bearer_token",
        "voice.transcriptions.create",
        "http.request",
    ]
    assert matching[0]["parent_span_id"] == matching[2]["span_id"]
    assert matching[1]["parent_span_id"] == matching[2]["span_id"]
    assert matching[1]["attributes"]["audio_size_bytes"] > 0
    assert matching[1]["attributes"]["provider"] == "fake-stt"
    assert matching[1]["attributes"]["transcript_length"] == len("Turn on the kitchen lights")
    assert matching[2]["status_code"] == 200


def test_unauthorized_request_writes_trace_error_metadata(tmp_path: Path) -> None:
    client = _make_client(tmp_path=tmp_path)

    with FIXTURE_PATH.open("rb") as fixture:
        response = client.post(
            "/v1/voice/transcriptions",
            files={"audio_file": ("silence-1s.wav", fixture, "audio/wav")},
        )

    assert response.status_code == 401

    entries = _read_log_entries(tmp_path / "core-api.jsonl")
    request_log = entries[-1]

    assert request_log["event_name"] == "http.request"
    assert request_log["status_code"] == 401
    assert request_log["error_code"] == "unauthorized"


def _make_client(tmp_path: Path | None = None) -> TestClient:
    settings = Settings(
        api_bearer_token="test-token",
        stt_provider="fake",
        backend_log_dir=tmp_path or Path("/tmp/jarvis-test-logs"),
    )
    return TestClient(create_app(settings=settings))


def _read_log_entries(log_path: Path) -> list[dict[str, Any]]:
    return [
        json.loads(line)
        for line in log_path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
from typing import Any
