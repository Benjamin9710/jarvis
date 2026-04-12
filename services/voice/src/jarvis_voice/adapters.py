from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import subprocess
from typing import Protocol

from .exceptions import AdapterExecutionError
from .models import TranscriptionRequest, TranscriptionResult


class SpeechToTextAdapter(Protocol):
    def transcribe(self, request: TranscriptionRequest) -> TranscriptionResult:
        ...


@dataclass(frozen=True, slots=True)
class FakeSpeechToTextAdapter:
    transcript_text: str = "Turn on the kitchen lights"
    language: str = "en"
    provider: str = "fake-stt"
    confidence: float | None = None

    def transcribe(self, request: TranscriptionRequest) -> TranscriptionResult:
        return TranscriptionResult(
            transcript_text=self.transcript_text,
            language=self.language,
            provider=self.provider,
            confidence=self.confidence,
        )


@dataclass(frozen=True, slots=True)
class WhisperCppSpeechToTextAdapter:
    binary_path: Path
    model_path: Path
    language: str = "en"
    threads: int = 4
    timeout_seconds: int = 120
    disable_gpu: bool = True

    def transcribe(self, request: TranscriptionRequest) -> TranscriptionResult:
        command = [
            str(self.binary_path),
            "--model",
            str(self.model_path),
            "--file",
            str(request.audio_path),
            "--language",
            request.language or self.language,
            "--threads",
            str(self.threads),
            "--no-timestamps",
            "--no-prints",
        ]

        if self.disable_gpu:
            command.append("--no-gpu")

        try:
            completed = subprocess.run(
                command,
                capture_output=True,
                check=False,
                text=True,
                timeout=self.timeout_seconds,
            )
        except FileNotFoundError as error:
            raise AdapterExecutionError("Configured whisper.cpp binary was not found.") from error
        except subprocess.TimeoutExpired as error:
            raise AdapterExecutionError("whisper.cpp timed out while transcribing audio.") from error
        except OSError as error:
            raise AdapterExecutionError("whisper.cpp could not be started.") from error

        if completed.returncode != 0:
            stderr = completed.stderr.strip()
            message = stderr or "whisper.cpp returned a non-zero exit code."
            raise AdapterExecutionError(message)

        transcript_text = completed.stdout.strip()

        return TranscriptionResult(
            transcript_text=transcript_text,
            language=request.language or self.language,
            provider="whisper.cpp",
            confidence=None,
        )
