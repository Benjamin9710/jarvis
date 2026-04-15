from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import subprocess
from typing import Protocol

from .exceptions import AdapterExecutionError, TextToSpeechError
from .models import (
    SynthesizedSpeech,
    TextToSpeechRequest,
    TranscriptionRequest,
    TranscriptionResult,
)
from .tts import XttsModelRuntime, build_silent_wav


class SpeechToTextAdapter(Protocol):
    def transcribe(self, request: TranscriptionRequest) -> TranscriptionResult:
        ...


class TextToSpeechAdapter(Protocol):
    def synthesize(self, request: TextToSpeechRequest) -> SynthesizedSpeech:
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


@dataclass(frozen=True, slots=True)
class FakeTextToSpeechAdapter:
    provider: str = "fake-tts"
    sample_rate_hz: int = 24_000

    def synthesize(self, request: TextToSpeechRequest) -> SynthesizedSpeech:
        _ = request
        return SynthesizedSpeech(
            audio_bytes=build_silent_wav(sample_rate_hz=self.sample_rate_hz),
            provider=self.provider,
            content_type="audio/wav",
            sample_rate_hz=self.sample_rate_hz,
        )


@dataclass(frozen=True, slots=True)
class XttsTextToSpeechAdapter:
    model_name: str
    speaker: str
    device: str = "auto"
    cache_dir: Path = Path("/tmp/jarvis-xtts-cache")
    _runtime: XttsModelRuntime = field(init=False, repr=False, compare=False)

    def __post_init__(self) -> None:
        object.__setattr__(
            self,
            "_runtime",
            XttsModelRuntime(
                model_name=self.model_name,
                device=self.device,
                cache_dir=self.cache_dir,
            ),
        )

    def synthesize(self, request: TextToSpeechRequest) -> SynthesizedSpeech:
        resolved_request = TextToSpeechRequest(
            text=request.text,
            language=request.language,
            speaker=request.speaker or self.speaker,
            speaker_wav=request.speaker_wav,
        )
        try:
            return self._runtime.synthesize(resolved_request)
        except TextToSpeechError:
            raise
