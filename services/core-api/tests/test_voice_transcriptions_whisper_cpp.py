from pathlib import Path
import os
import re

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app


FIXTURE_PATH = Path(__file__).resolve().parents[2] / "voice" / "tests" / "fixtures" / "jfk.wav"
TOKEN = "test-token"


def test_voice_transcription_with_whisper_cpp_returns_real_transcript() -> None:
    binary_path = os.environ.get("JARVIS_WHISPER_CPP_TEST_BINARY_PATH")
    model_path = os.environ.get("JARVIS_WHISPER_CPP_TEST_MODEL_PATH")

    if not binary_path or not model_path:
        pytest.skip("Set JARVIS_WHISPER_CPP_TEST_BINARY_PATH and JARVIS_WHISPER_CPP_TEST_MODEL_PATH to run whisper.cpp integration.")

    if not Path(binary_path).exists():
        pytest.skip(f"whisper.cpp binary not found at {binary_path}")

    if not Path(model_path).exists():
        pytest.skip(f"whisper.cpp model not found at {model_path}")

    client = TestClient(
        create_app(
            settings=Settings(
                api_bearer_token=TOKEN,
                stt_provider="whisper.cpp",
                whisper_cpp_binary_path=Path(binary_path),
                whisper_cpp_model_path=Path(model_path),
            )
        )
    )

    with FIXTURE_PATH.open("rb") as fixture:
        response = client.post(
            "/v1/voice/transcriptions",
            headers={"Authorization": f"Bearer {TOKEN}"},
            files={"audio_file": (FIXTURE_PATH.name, fixture, "audio/wav")},
            data={"client_request_id": "whisper-integration"},
        )

    assert response.status_code == 200
    payload = response.json()
    normalized = _normalize_for_assertion(payload["normalized_text"])

    assert payload["request_id"] == "whisper-integration"
    assert payload["provider"] == "whisper.cpp"
    assert payload["language"] == "en"
    assert payload["duration_ms"] > 0
    assert "ask" in normalized
    assert "country" in normalized


def _normalize_for_assertion(text: str) -> str:
    return re.sub(r"[^a-z0-9\s]+", "", text.lower())
