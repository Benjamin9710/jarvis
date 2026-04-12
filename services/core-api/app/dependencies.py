from __future__ import annotations

from typing import Annotated
import uuid

from fastapi import Form, Request

from jarvis_voice import FakeSpeechToTextAdapter, VoiceTranscriptionService, WhisperCppSpeechToTextAdapter

from .config import Settings
from .telemetry import current_request_id, set_request_id


def build_transcription_service(settings: Settings) -> VoiceTranscriptionService:
    if settings.stt_provider == "whisper.cpp":
        adapter = WhisperCppSpeechToTextAdapter(
            binary_path=settings.whisper_cpp_binary_path,
            model_path=settings.whisper_cpp_model_path,
            threads=settings.whisper_cpp_threads,
            timeout_seconds=settings.transcription_timeout_seconds,
        )
    else:
        adapter = FakeSpeechToTextAdapter()

    return VoiceTranscriptionService(adapter=adapter, temp_dir=settings.temp_audio_dir)


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_transcription_service(request: Request) -> VoiceTranscriptionService:
    return request.app.state.transcription_service


def bind_request_context(
    client_request_id: Annotated[str | None, Form()] = None,
) -> str:
    request_id = client_request_id or current_request_id() or str(uuid.uuid4())
    set_request_id(request_id)
    return request_id
