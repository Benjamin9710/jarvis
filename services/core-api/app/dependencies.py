from __future__ import annotations

from typing import Annotated
import uuid

from fastapi import Form, Request

from jarvis_voice import (
    FakeSpeechToTextAdapter,
    FakeTextToSpeechAdapter,
    JarvisResponseComposer,
    TextToSpeechService,
    VoiceTranscriptionService,
    WhisperCppSpeechToTextAdapter,
    XttsTextToSpeechAdapter,
)

from .config import Settings
from .interactions import MockLightCommandExecutor, NarrowLightCommandParser, VoiceInteractionService
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


def build_text_to_speech_service(settings: Settings) -> TextToSpeechService:
    if settings.tts_provider == "xtts":
        adapter = XttsTextToSpeechAdapter(
            model_name=settings.tts_model_name,
            speaker=settings.tts_speaker,
            device=settings.tts_device,
            cache_dir=settings.tts_cache_dir,
        )
    else:
        adapter = FakeTextToSpeechAdapter()

    return TextToSpeechService(adapter=adapter)


def build_interaction_service(
    settings: Settings,
    transcription_service: VoiceTranscriptionService,
    tts_service: TextToSpeechService,
) -> VoiceInteractionService:
    provider_name = "xtts-v2" if settings.tts_provider == "xtts" else "fake-tts"
    return VoiceInteractionService(
        transcription_service=transcription_service,
        tts_service=tts_service,
        parser=NarrowLightCommandParser(),
        executor=MockLightCommandExecutor(),
        response_composer=JarvisResponseComposer(),
        tts_provider_name=provider_name,
        tts_language=settings.tts_language,
        tts_speaker=settings.tts_speaker,
    )


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_transcription_service(request: Request) -> VoiceTranscriptionService:
    return request.app.state.transcription_service


def get_interaction_service(request: Request) -> VoiceInteractionService:
    return request.app.state.interaction_service


def bind_request_context(
    client_request_id: Annotated[str | None, Form()] = None,
) -> str:
    request_id = client_request_id or current_request_id() or str(uuid.uuid4())
    set_request_id(request_id)
    return request_id
