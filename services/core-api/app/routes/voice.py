from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, UploadFile
from fastapi.responses import JSONResponse

from jarvis_voice import AudioUpload, CompletedTranscription, TranscriptionError, VoiceTranscriptionService

from app.auth import verify_bearer_token
from app.dependencies import bind_request_context, get_interaction_service, get_transcription_service
from app.interactions import VoiceInteractionResult, VoiceInteractionService
from app.errors import build_error_response
from app.schemas import ErrorResponse, TranscriptionSuccessResponse, VoiceInteractionSuccessResponse
from app.telemetry import start_span


router = APIRouter(prefix="/v1/voice", tags=["voice"])


@router.post(
    "/transcriptions",
    response_model=TranscriptionSuccessResponse,
    responses={
        400: {"model": ErrorResponse},
        401: {"model": ErrorResponse},
        415: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def create_transcription(
    request_id: Annotated[str, Depends(bind_request_context)],
    audio_file: UploadFile = File(...),
    device_name: Annotated[str | None, Form()] = None,
    _authorized: None = Depends(verify_bearer_token),
    transcription_service: VoiceTranscriptionService = Depends(get_transcription_service),
) -> TranscriptionSuccessResponse | JSONResponse:
    audio_bytes = await audio_file.read()
    with start_span(
        "voice.transcriptions.create",
        audio_filename=audio_file.filename or "audio.wav",
        audio_content_type=audio_file.content_type or "",
        audio_size_bytes=len(audio_bytes),
        device_name_present=device_name is not None,
    ) as span:
        try:
            transcription = transcription_service.transcribe_upload(
                AudioUpload(
                    filename=audio_file.filename or "audio.wav",
                    data=audio_bytes,
                    content_type=audio_file.content_type,
                ),
                request_id=request_id,
            )
        except TranscriptionError as error:
            span.set_attribute("transcription_status", "failed")
            span.set_attribute("error_code", error.error_code)
            return build_error_response(
                status_code=error.status_code,
                request_id=request_id,
                error_code=error.error_code,
                message=error.message,
            )

        span.set_attribute("transcription_status", "succeeded")
        span.set_attribute("provider", transcription.provider)
        span.set_attribute("duration_ms", transcription.duration_ms)
        span.set_attribute("transcript_length", len(transcription.transcript_text))
        return _to_success_response(transcription)


@router.post(
    "/interactions",
    response_model=VoiceInteractionSuccessResponse,
    responses={
        400: {"model": ErrorResponse},
        401: {"model": ErrorResponse},
        415: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)
async def create_interaction(
    request_id: Annotated[str, Depends(bind_request_context)],
    audio_file: UploadFile = File(...),
    device_name: Annotated[str | None, Form()] = None,
    _authorized: None = Depends(verify_bearer_token),
    interaction_service: VoiceInteractionService = Depends(get_interaction_service),
) -> VoiceInteractionSuccessResponse | JSONResponse:
    audio_bytes = await audio_file.read()
    with start_span(
        "voice.interactions.create",
        audio_filename=audio_file.filename or "audio.wav",
        audio_content_type=audio_file.content_type or "",
        audio_size_bytes=len(audio_bytes),
        device_name_present=device_name is not None,
    ) as span:
        try:
            interaction = interaction_service.process_upload(
                AudioUpload(
                    filename=audio_file.filename or "audio.wav",
                    data=audio_bytes,
                    content_type=audio_file.content_type,
                ),
                request_id=request_id,
            )
        except TranscriptionError as error:
            span.set_attribute("interaction_status", "failed")
            span.set_attribute("error_code", error.error_code)
            return build_error_response(
                status_code=error.status_code,
                request_id=request_id,
                error_code=error.error_code,
                message=error.message,
            )

        span.set_attribute("interaction_status", "succeeded")
        span.set_attribute("stt_provider", interaction.stt_provider)
        span.set_attribute("tts_provider", interaction.tts_provider)
        span.set_attribute("command_status", interaction.command_status)
        span.set_attribute("tts_status", interaction.tts_status)
        return _to_interaction_response(interaction)


def _to_success_response(transcription: CompletedTranscription) -> TranscriptionSuccessResponse:
    return TranscriptionSuccessResponse(
        request_id=transcription.request_id,
        transcript_text=transcription.transcript_text,
        normalized_text=transcription.normalized_text,
        language=transcription.language,
        duration_ms=transcription.duration_ms,
        provider=transcription.provider,
        confidence=transcription.confidence,
    )


def _to_interaction_response(interaction: VoiceInteractionResult) -> VoiceInteractionSuccessResponse:
    return VoiceInteractionSuccessResponse(
        request_id=interaction.request_id,
        transcript_text=interaction.transcript_text,
        normalized_text=interaction.normalized_text,
        command_status=interaction.command_status,
        command_action=interaction.command_action,
        command_target=interaction.command_target,
        summary_text=interaction.summary_text,
        spoken_text=interaction.spoken_text,
        response_audio_base64=interaction.response_audio_base64,
        response_audio_content_type=interaction.response_audio_content_type,
        response_audio_sample_rate_hz=interaction.response_audio_sample_rate_hz,
        stt_provider=interaction.stt_provider,
        tts_provider=interaction.tts_provider,
        tts_status=interaction.tts_status,
    )
