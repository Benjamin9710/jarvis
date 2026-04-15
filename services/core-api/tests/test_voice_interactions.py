from pathlib import Path
import json
from typing import Any, cast

from fastapi.testclient import TestClient

from app.config import Settings
from app.interactions import NarrowLightCommandParser, VoiceInteractionService
from app.main import create_app
from jarvis_voice import (
    AudioUpload,
    FakeSpeechToTextAdapter,
    JarvisResponseComposer,
    TextToSpeechError,
    TextToSpeechRequest,
    TextToSpeechService,
    VoiceTranscriptionService,
)


FIXTURE_PATH = Path(__file__).resolve().parents[2] / "voice" / "tests" / "fixtures" / "silence-1s.wav"


class FailingTextToSpeechService(TextToSpeechService):
    def __init__(self) -> None:
        pass

    def synthesize(self, request: TextToSpeechRequest):  # type: ignore[override]
        _ = request
        raise TextToSpeechError("tts failed")


def test_light_command_parser_accepts_turn_off_with_optional_the() -> None:
    parser = NarrowLightCommandParser()

    parsed = parser.parse("turn off the living room lights")

    assert parsed is not None
    assert parsed.action == "turn_off"
    assert parsed.target == "living room"


def test_light_command_parser_accepts_terminal_punctuation() -> None:
    parser = NarrowLightCommandParser()

    parsed = parser.parse("turn on the kitchen lights.")

    assert parsed is not None
    assert parsed.action == "turn_on"
    assert parsed.target == "kitchen"


def test_voice_interaction_returns_summary_spoken_text_and_audio() -> None:
    client = _make_client()

    with FIXTURE_PATH.open("rb") as fixture:
        response = client.post(
            "/v1/voice/interactions",
            headers={"Authorization": "Bearer test-token"},
            files={"audio_file": ("silence-1s.wav", fixture, "audio/wav")},
            data={"client_request_id": "interaction-success", "device_name": "CI iPhone"},
        )

    assert response.status_code == 200
    assert response.json() == {
        "request_id": "interaction-success",
        "transcript_text": "Turn on the kitchen lights",
        "normalized_text": "turn on the kitchen lights",
        "command_status": "succeeded",
        "command_action": "turn_on",
        "command_target": "kitchen",
        "summary_text": "Kitchen lights turned on",
        "spoken_text": "Certainly. The kitchen lights are now on.",
        "response_audio_base64": response.json()["response_audio_base64"],
        "response_audio_content_type": "audio/wav",
        "response_audio_sample_rate_hz": 24000,
        "stt_provider": "fake-stt",
        "tts_provider": "fake-tts",
        "tts_status": "succeeded",
    }
    assert response.json()["response_audio_base64"]


def test_voice_interaction_returns_unsupported_for_other_commands() -> None:
    client = _make_client(
        transcript_text="Open the garage door",
        request_log_dir=Path("/tmp/jarvis-test-logs-interactions-unsupported"),
    )

    with FIXTURE_PATH.open("rb") as fixture:
        response = client.post(
            "/v1/voice/interactions",
            headers={"Authorization": "Bearer test-token"},
            files={"audio_file": ("silence-1s.wav", fixture, "audio/wav")},
            data={"client_request_id": "interaction-unsupported"},
        )

    assert response.status_code == 200
    assert response.json()["command_status"] == "unsupported"
    assert response.json()["command_action"] is None
    assert response.json()["command_target"] is None
    assert response.json()["summary_text"] == "Command not available"
    assert response.json()["spoken_text"] == "I'm afraid I can't do that just yet."
    assert response.json()["tts_status"] == "succeeded"


def test_voice_interaction_returns_text_when_tts_fails() -> None:
    client = _make_client()
    app = cast(Any, client.app)
    app.state.interaction_service = VoiceInteractionService(
        transcription_service=VoiceTranscriptionService(adapter=FakeSpeechToTextAdapter()),
        tts_service=FailingTextToSpeechService(),
        parser=NarrowLightCommandParser(),
        executor=app.state.interaction_service._executor,
        response_composer=JarvisResponseComposer(),
        tts_provider_name="xtts-v2",
        tts_language="en",
        tts_speaker="Craig Gutsy",
    )

    with FIXTURE_PATH.open("rb") as fixture:
        response = client.post(
            "/v1/voice/interactions",
            headers={"Authorization": "Bearer test-token"},
            files={"audio_file": ("silence-1s.wav", fixture, "audio/wav")},
            data={"client_request_id": "interaction-tts-failed"},
        )

    assert response.status_code == 200
    assert response.json()["summary_text"] == "Kitchen lights turned on"
    assert response.json()["spoken_text"] == "Certainly. The kitchen lights are now on."
    assert response.json()["response_audio_base64"] is None
    assert response.json()["response_audio_content_type"] is None
    assert response.json()["response_audio_sample_rate_hz"] is None
    assert response.json()["tts_status"] == "failed"
    assert response.json()["tts_provider"] == "xtts-v2"


def test_voice_interaction_writes_trace_metadata_without_transcript_text(tmp_path: Path) -> None:
    client = _make_client(request_log_dir=tmp_path)

    with FIXTURE_PATH.open("rb") as fixture:
        response = client.post(
            "/v1/voice/interactions",
            headers={"Authorization": "Bearer test-token"},
            files={"audio_file": ("silence-1s.wav", fixture, "audio/wav")},
            data={"client_request_id": "interaction-trace", "device_name": "CI iPhone"},
        )

    assert response.status_code == 200

    entries = _read_log_entries(tmp_path / "core-api.jsonl")
    matching = [entry for entry in entries if entry["request_id"] == "interaction-trace"]
    event_names = [entry["event_name"] for entry in matching]

    assert event_names == [
        "auth.verify_bearer_token",
        "voice.interactions.create",
        "http.request",
    ]
    assert matching[1]["attributes"]["command_status"] == "succeeded"
    assert matching[1]["attributes"]["tts_status"] == "succeeded"
    assert "transcript_text" not in matching[1]["attributes"]
    assert "summary_text" not in matching[1]["attributes"]


def _make_client(
    *,
    transcript_text: str = "Turn on the kitchen lights",
    request_log_dir: Path | None = None,
) -> TestClient:
    settings = Settings(
        api_bearer_token="test-token",
        stt_provider="fake",
        tts_provider="fake",
        backend_log_dir=request_log_dir or Path("/tmp/jarvis-test-logs-interactions"),
    )
    client = TestClient(create_app(settings=settings))
    app = cast(Any, client.app)
    app.state.transcription_service = VoiceTranscriptionService(
        adapter=FakeSpeechToTextAdapter(transcript_text=transcript_text)
    )
    app.state.interaction_service = VoiceInteractionService(
        transcription_service=app.state.transcription_service,
        tts_service=app.state.tts_service,
        parser=NarrowLightCommandParser(),
        executor=app.state.interaction_service._executor,
        response_composer=JarvisResponseComposer(),
        tts_provider_name="fake-tts",
        tts_language="en",
        tts_speaker="Craig Gutsy",
    )
    return client


def _read_log_entries(log_path: Path) -> list[dict[str, Any]]:
    return [
        json.loads(line)
        for line in log_path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
