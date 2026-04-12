from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import tempfile
import wave
import uuid

from .adapters import SpeechToTextAdapter
from .exceptions import InvalidAudioError, UnsupportedAudioFormatError
from .models import CompletedTranscription, TranscriptionRequest
from .normalization import normalize_transcript


@dataclass(frozen=True, slots=True)
class AudioUpload:
    filename: str
    data: bytes
    content_type: str | None = None


class VoiceTranscriptionService:
    def __init__(self, adapter: SpeechToTextAdapter, temp_dir: Path | None = None) -> None:
        self._adapter = adapter
        self._temp_dir = temp_dir

    def transcribe_upload(self, upload: AudioUpload, request_id: str | None = None) -> CompletedTranscription:
        resolved_request_id = request_id or str(uuid.uuid4())
        audio_bytes = upload.data

        if not audio_bytes:
            raise InvalidAudioError()

        suffix = self._validated_suffix(upload)
        temp_path = self._write_temp_file(audio_bytes, suffix)

        try:
            duration_ms = self._read_duration_ms(temp_path)
            result = self._adapter.transcribe(
                TranscriptionRequest(audio_path=temp_path, language="en")
            )
            return CompletedTranscription(
                request_id=resolved_request_id,
                transcript_text=result.transcript_text.strip(),
                normalized_text=normalize_transcript(result.transcript_text),
                language=result.language,
                duration_ms=duration_ms,
                provider=result.provider,
                confidence=result.confidence,
            )
        finally:
            temp_path.unlink(missing_ok=True)

    def _validated_suffix(self, upload: AudioUpload) -> str:
        suffix = Path(upload.filename or "audio.wav").suffix.lower() or ".wav"
        content_type = (upload.content_type or "").lower()

        allowed_content_types = {"", "audio/wav", "audio/x-wav", "audio/wave", "application/octet-stream"}
        if suffix != ".wav":
            raise UnsupportedAudioFormatError("v1 only accepts WAV uploads.")

        if content_type not in allowed_content_types:
            raise UnsupportedAudioFormatError("v1 only accepts WAV uploads.")

        return suffix

    def _write_temp_file(self, audio_bytes: bytes, suffix: str) -> Path:
        if self._temp_dir is not None:
            self._temp_dir.mkdir(parents=True, exist_ok=True)

        with tempfile.NamedTemporaryFile(
            delete=False,
            dir=self._temp_dir,
            prefix="jarvis-transcription-",
            suffix=suffix,
        ) as handle:
            handle.write(audio_bytes)
            return Path(handle.name)

    def _read_duration_ms(self, audio_path: Path) -> int:
        try:
            with wave.open(str(audio_path), "rb") as wav_file:
                frame_count = wav_file.getnframes()
                frame_rate = wav_file.getframerate()
        except (wave.Error, EOFError) as error:
            raise UnsupportedAudioFormatError() from error

        if frame_rate <= 0:
            raise UnsupportedAudioFormatError()

        return int((frame_count / frame_rate) * 1000)
