from __future__ import annotations

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = "ok"


class TranscriptionSuccessResponse(BaseModel):
    request_id: str = Field(min_length=1)
    transcript_text: str
    normalized_text: str
    language: str
    duration_ms: int
    provider: str
    confidence: float | None = None


class VoiceInteractionSuccessResponse(BaseModel):
    request_id: str = Field(min_length=1)
    transcript_text: str
    normalized_text: str
    command_status: str
    command_action: str | None = None
    command_target: str | None = None
    summary_text: str
    spoken_text: str
    response_audio_base64: str | None = None
    response_audio_content_type: str | None = None
    response_audio_sample_rate_hz: int | None = None
    stt_provider: str
    tts_provider: str
    tts_status: str


class ErrorResponse(BaseModel):
    request_id: str | None = None
    error_code: str
    message: str
