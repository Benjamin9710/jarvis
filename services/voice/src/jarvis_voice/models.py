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
