# Voice Interaction

This document defines the v1 end-to-end contract for uploading a finalized voice clip and receiving a Jarvis-style command response with optional synthesized audio.

## Status

- Scope: transcription, narrow deterministic light parsing, mocked command execution, response text, and optional TTS audio
- Out of scope: real device execution, streaming playback, and local LLM routing
- The iPhone app should use this contract for the Jarvis response slice

## Endpoint

- Method: `POST`
- Path: `/v1/voice/interactions`
- Content type: `multipart/form-data`
- Auth: `Authorization: Bearer <token>`

## Request Fields

### Multipart Parts

- `audio_file`
  - required
  - v1 expects a WAV upload
- `client_request_id`
  - optional
  - client-generated UUID used for correlation
- `device_name`
  - optional
  - diagnostic label such as `Ben iPhone`

## Success Response

```json
{
  "request_id": "b407accc-2fd5-4c82-a3f9-af1dc364c4da",
  "transcript_text": "Turn on the kitchen lights",
  "normalized_text": "turn on the kitchen lights",
  "command_status": "succeeded",
  "command_action": "turn_on",
  "command_target": "kitchen",
  "summary_text": "Kitchen lights turned on",
  "spoken_text": "Certainly. The kitchen lights are now on.",
  "response_audio_base64": "UklGR...",
  "response_audio_content_type": "audio/wav",
  "response_audio_sample_rate_hz": 24000,
  "stt_provider": "whisper.cpp",
  "tts_provider": "xtts-v2",
  "tts_status": "succeeded"
}
```

## Field Semantics

- `command_status`
  - `succeeded` when the narrow light command matcher recognizes the request
  - `unsupported` when the transcript is valid but the command is outside the implemented slice
- `command_action`
  - `turn_on`, `turn_off`, or `null`
- `command_target`
  - normalized target phrase without the trailing `light` / `lights`, or `null`
- `summary_text`
  - concise UI-first confirmation text
- `spoken_text`
  - Jarvis-style spoken reply used for TTS
- `response_audio_base64`
  - nullable base64-encoded WAV payload
- `response_audio_content_type`
  - nullable MIME type for the audio payload
- `response_audio_sample_rate_hz`
  - nullable sample rate for the synthesized WAV
- `stt_provider`
  - speech-to-text adapter identifier
- `tts_provider`
  - text-to-speech adapter identifier
- `tts_status`
  - `succeeded` or `failed`

## Unsupported Command Example

Unsupported commands still return `200` with deterministic fallback text.

```json
{
  "request_id": "7fb3b0ab-3f9a-4b7f-a7a1-b3345384a1d8",
  "transcript_text": "Open the garage door",
  "normalized_text": "open the garage door",
  "command_status": "unsupported",
  "command_action": null,
  "command_target": null,
  "summary_text": "Command not available",
  "spoken_text": "I'm afraid I can't do that just yet.",
  "response_audio_base64": "UklGR...",
  "response_audio_content_type": "audio/wav",
  "response_audio_sample_rate_hz": 24000,
  "stt_provider": "whisper.cpp",
  "tts_provider": "xtts-v2",
  "tts_status": "succeeded"
}
```

## TTS Failure Behavior

If command parsing succeeds or falls back successfully but speech synthesis fails, the route still returns `200`.

```json
{
  "request_id": "2af5875a-02ed-4927-b54c-22a446e11830",
  "transcript_text": "Turn on the kitchen lights",
  "normalized_text": "turn on the kitchen lights",
  "command_status": "succeeded",
  "command_action": "turn_on",
  "command_target": "kitchen",
  "summary_text": "Kitchen lights turned on",
  "spoken_text": "Certainly. The kitchen lights are now on.",
  "response_audio_base64": null,
  "response_audio_content_type": null,
  "response_audio_sample_rate_hz": null,
  "stt_provider": "whisper.cpp",
  "tts_provider": "xtts-v2",
  "tts_status": "failed"
}
```

## Failure Response

Route-level failures use the shared error envelope.

```json
{
  "request_id": "b407accc-2fd5-4c82-a3f9-af1dc364c4da",
  "error_code": "unsupported_audio_format",
  "message": "v1 only accepts WAV uploads."
}
```

## Compatibility Notes

- `/v1/voice/transcriptions` remains available as the lower-level STT contract.
- This interaction contract is intentionally narrow for the first Jarvis response slice.
