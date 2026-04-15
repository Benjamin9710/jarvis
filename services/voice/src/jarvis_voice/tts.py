from __future__ import annotations

from io import BytesIO
import importlib
import os
from pathlib import Path
import tempfile
import threading
import wave

from .exceptions import TextToSpeechError
from .models import SynthesizedSpeech, TextToSpeechRequest


class TextToSpeechService:
    def __init__(self, adapter) -> None:
        self._adapter = adapter

    def synthesize(self, request: TextToSpeechRequest) -> SynthesizedSpeech:
        if not request.text.strip():
            raise TextToSpeechError("Audio response could not be synthesized.")
        return self._adapter.synthesize(request)


def build_silent_wav(*, duration_ms: int = 240, sample_rate_hz: int = 24_000) -> bytes:
    frame_count = max(1, int(sample_rate_hz * duration_ms / 1000))
    with BytesIO() as buffer:
        with wave.open(buffer, "wb") as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(sample_rate_hz)
            wav_file.writeframes(b"\x00\x00" * frame_count)
        return buffer.getvalue()


class XttsModelRuntime:
    def __init__(
        self,
        *,
        model_name: str,
        device: str,
        cache_dir: Path,
    ) -> None:
        self._model_name = model_name
        self._device = device
        self._cache_dir = cache_dir
        self._lock = threading.Lock()
        self._tts = None

    def synthesize(self, request: TextToSpeechRequest) -> SynthesizedSpeech:
        tts = self._load()

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as handle:
            output_path = Path(handle.name)

        try:
            kwargs: dict[str, object] = {
                "text": request.text,
                "language": request.language,
                "file_path": str(output_path),
            }
            if request.speaker_wav is not None:
                kwargs["speaker_wav"] = str(request.speaker_wav)
            elif request.speaker is not None:
                kwargs["speaker"] = request.speaker

            tts.tts_to_file(**kwargs)
            audio_bytes = output_path.read_bytes()
            sample_rate_hz = _read_sample_rate(output_path)
            return SynthesizedSpeech(
                audio_bytes=audio_bytes,
                provider="xtts-v2",
                content_type="audio/wav",
                sample_rate_hz=sample_rate_hz,
            )
        except TextToSpeechError:
            raise
        except Exception as error:  # pragma: no cover - exercised in integration when dependency is installed
            raise TextToSpeechError(f"XTTS synthesis failed: {error}") from error
        finally:
            output_path.unlink(missing_ok=True)

    def _load(self):
        with self._lock:
            if self._tts is not None:
                return self._tts

            try:
                torch = importlib.import_module("torch")
                tts_module = importlib.import_module("TTS.api")
                TTS = tts_module.TTS
            except ImportError as error:  # pragma: no cover - depends on optional runtime dependency
                raise TextToSpeechError(
                    "XTTS runtime dependencies are not installed. Install coqui-tts[codec], torch, and torchaudio."
                ) from error

            self._cache_dir.mkdir(parents=True, exist_ok=True)
            os.environ.setdefault("HF_HOME", str(self._cache_dir))
            os.environ.setdefault("TTS_HOME", str(self._cache_dir))
            os.environ.setdefault("MPLCONFIGDIR", str(self._cache_dir / "matplotlib"))
            os.environ.setdefault("COQUI_TOS_AGREED", "1")

            resolved_device = _resolve_device(torch=torch, preferred_device=self._device)
            try:
                self._tts = TTS(self._model_name).to(resolved_device)
            except Exception as error:  # pragma: no cover - exercised in integration when dependency is installed
                raise TextToSpeechError(f"XTTS model could not be loaded: {error}") from error
            return self._tts


def _resolve_device(*, torch, preferred_device: str) -> str:
    if preferred_device != "auto":
        return preferred_device
    if torch.cuda.is_available():
        return "cuda"
    if getattr(torch.backends, "mps", None) is not None and torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def _read_sample_rate(audio_path: Path) -> int:
    try:
        with wave.open(str(audio_path), "rb") as wav_file:
            return wav_file.getframerate()
    except (wave.Error, EOFError) as error:
        raise TextToSpeechError("XTTS produced an unreadable WAV response.") from error
