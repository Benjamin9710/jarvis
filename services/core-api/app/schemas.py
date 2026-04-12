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


class ErrorResponse(BaseModel):
    request_id: str | None = None
    error_code: str
    message: str
