from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import pytest

from jarvis_voice.adapters import WhisperCppSpeechToTextAdapter
from jarvis_voice.exceptions import AdapterExecutionError
from jarvis_voice.models import TranscriptionRequest


def test_whisper_cpp_adapter_returns_stdout_transcript(tmp_path: Path) -> None:
    audio_path = tmp_path / "sample.wav"
    audio_path.write_bytes(b"wav")

    adapter = WhisperCppSpeechToTextAdapter(
        binary_path=Path("/opt/whisper.cpp/whisper-cli"),
        model_path=Path("/opt/whisper.cpp/models/ggml-base.en.bin"),
        threads=6,
    )

    with patch("jarvis_voice.adapters.subprocess.run") as run_mock:
        run_mock.return_value = SimpleNamespace(returncode=0, stdout="Turn on the kitchen lights\n", stderr="")

        result = adapter.transcribe(TranscriptionRequest(audio_path=audio_path, language="en"))

    command = run_mock.call_args.args[0]
    assert command[:4] == [
        "/opt/whisper.cpp/whisper-cli",
        "--model",
        "/opt/whisper.cpp/models/ggml-base.en.bin",
        "--file",
    ]
    assert "--no-gpu" in command
    assert result.transcript_text == "Turn on the kitchen lights"
    assert result.provider == "whisper.cpp"


def test_whisper_cpp_adapter_raises_on_non_zero_exit(tmp_path: Path) -> None:
    audio_path = tmp_path / "sample.wav"
    audio_path.write_bytes(b"wav")

    adapter = WhisperCppSpeechToTextAdapter(
        binary_path=Path("/opt/whisper.cpp/whisper-cli"),
        model_path=Path("/opt/whisper.cpp/models/ggml-base.en.bin"),
    )

    with patch("jarvis_voice.adapters.subprocess.run") as run_mock:
        run_mock.return_value = SimpleNamespace(returncode=1, stdout="", stderr="bad audio")

        with pytest.raises(AdapterExecutionError, match="bad audio"):
            adapter.transcribe(TranscriptionRequest(audio_path=audio_path, language="en"))
