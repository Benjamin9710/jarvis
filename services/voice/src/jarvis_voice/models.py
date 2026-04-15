from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class TranscriptionRequest:
    audio_path: Path
    language: str = "en"


@dataclass(frozen=True, slots=True)
class TranscriptionResult:
    transcript_text: str
    language: str
    provider: str
    confidence: float | None = None


@dataclass(frozen=True, slots=True)
class CompletedTranscription:
    request_id: str
    transcript_text: str
    normalized_text: str
    language: str
    duration_ms: int
    provider: str
    confidence: float | None = None


@dataclass(frozen=True, slots=True)
class TextToSpeechRequest:
    text: str
    language: str = "en"
    speaker: str | None = None
    speaker_wav: Path | None = None


@dataclass(frozen=True, slots=True)
class SynthesizedSpeech:
    audio_bytes: bytes
    provider: str
    content_type: str = "audio/wav"
    sample_rate_hz: int | None = None
