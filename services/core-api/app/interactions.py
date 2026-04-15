from __future__ import annotations

from dataclasses import dataclass
import base64
import re
from typing import Literal

from jarvis_voice import (
    AudioUpload,
    JarvisResponseComposer,
    TextToSpeechError,
    TextToSpeechRequest,
    TextToSpeechService,
    VoiceTranscriptionService,
)


CommandAction = Literal["turn_on", "turn_off"]
CommandStatus = Literal["succeeded", "unsupported"]
TtsStatus = Literal["succeeded", "failed"]

_LIGHT_COMMAND_PATTERN = re.compile(
    r"^turn (?P<direction>on|off) (?:the )?(?P<target>.+?) lights?$"
)
_TRAILING_PUNCTUATION_PATTERN = re.compile(r"[.!?]+$")


@dataclass(frozen=True, slots=True)
class ParsedLightCommand:
    action: CommandAction
    target: str


@dataclass(frozen=True, slots=True)
class VoiceInteractionResult:
    request_id: str
    transcript_text: str
    normalized_text: str
    command_status: CommandStatus
    command_action: CommandAction | None
    command_target: str | None
    summary_text: str
    spoken_text: str
    response_audio_base64: str | None
    response_audio_content_type: str | None
    response_audio_sample_rate_hz: int | None
    stt_provider: str
    tts_provider: str
    tts_status: TtsStatus


class NarrowLightCommandParser:
    def parse(self, normalized_text: str) -> ParsedLightCommand | None:
        candidate = _TRAILING_PUNCTUATION_PATTERN.sub("", normalized_text.strip())
        match = _LIGHT_COMMAND_PATTERN.match(candidate)
        if not match:
            return None

        raw_target = " ".join(match.group("target").strip().split())
        if not raw_target:
            return None

        action = "turn_on" if match.group("direction") == "on" else "turn_off"
        return ParsedLightCommand(action=action, target=raw_target)


class MockLightCommandExecutor:
    def execute(self, command: ParsedLightCommand) -> ParsedLightCommand:
        return command


class VoiceInteractionService:
    def __init__(
        self,
        *,
        transcription_service: VoiceTranscriptionService,
        tts_service: TextToSpeechService,
        parser: NarrowLightCommandParser,
        executor: MockLightCommandExecutor,
        response_composer: JarvisResponseComposer,
        tts_provider_name: str,
        tts_language: str,
        tts_speaker: str | None,
    ) -> None:
        self._transcription_service = transcription_service
        self._tts_service = tts_service
        self._parser = parser
        self._executor = executor
        self._response_composer = response_composer
        self._tts_provider_name = tts_provider_name
        self._tts_language = tts_language
        self._tts_speaker = tts_speaker

    def process_upload(self, upload: AudioUpload, request_id: str) -> VoiceInteractionResult:
        transcription = self._transcription_service.transcribe_upload(upload, request_id=request_id)

        parsed_command = self._parser.parse(transcription.normalized_text)
        if parsed_command is None:
            response_text = self._response_composer.compose_unsupported()
            command_status: CommandStatus = "unsupported"
            command_action: CommandAction | None = None
            command_target: str | None = None
        else:
            executed_command = self._executor.execute(parsed_command)
            response_text = self._response_composer.compose_success(
                executed_command.action, executed_command.target
            )
            command_status = "succeeded"
            command_action = executed_command.action
            command_target = executed_command.target

        response_audio_base64: str | None = None
        response_audio_content_type: str | None = None
        response_audio_sample_rate_hz: int | None = None
        tts_status: TtsStatus = "failed"
        tts_provider = self._tts_provider_name

        try:
            synthesized = self._tts_service.synthesize(
                TextToSpeechRequest(
                    text=response_text.spoken_text,
                    language=self._tts_language,
                    speaker=self._tts_speaker,
                )
            )
            response_audio_base64 = base64.b64encode(synthesized.audio_bytes).decode("ascii")
            response_audio_content_type = synthesized.content_type
            response_audio_sample_rate_hz = synthesized.sample_rate_hz
            tts_status = "succeeded"
            tts_provider = synthesized.provider
        except TextToSpeechError:
            pass

        return VoiceInteractionResult(
            request_id=transcription.request_id,
            transcript_text=transcription.transcript_text,
            normalized_text=transcription.normalized_text,
            command_status=command_status,
            command_action=command_action,
            command_target=command_target,
            summary_text=response_text.summary_text,
            spoken_text=response_text.spoken_text,
            response_audio_base64=response_audio_base64,
            response_audio_content_type=response_audio_content_type,
            response_audio_sample_rate_hz=response_audio_sample_rate_hz,
            stt_provider=transcription.provider,
            tts_provider=tts_provider,
            tts_status=tts_status,
        )
