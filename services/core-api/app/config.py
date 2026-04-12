from __future__ import annotations

from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


REPO_ROOT = Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="JARVIS_",
        env_file=".env",
        extra="ignore",
    )

    api_bearer_token: str = "development-token"
    stt_provider: Literal["fake", "whisper.cpp"] = "fake"
    whisper_cpp_binary_path: Path = Path("/opt/whisper.cpp/build/bin/whisper-cli")
    whisper_cpp_model_path: Path = Path("/opt/whisper.cpp/models/ggml-base.en.bin")
    whisper_cpp_threads: int = 4
    transcription_timeout_seconds: int = 120
    temp_audio_dir: Path = Path("/tmp/jarvis-audio")
    backend_log_dir: Path = REPO_ROOT / ".artifacts" / "logs" / "backend"
