# Voice Transcription

This document defines the v1 contract for uploading a finalized voice clip to the local backend and receiving a normalized transcript.

## Status

This is the first implemented backend contract in the voice pipeline.

- Scope: transcription only
- Out of scope: intent parsing, device routing, text-to-speech
- The iPhone app now uses this contract for its post-capture upload flow.
- The higher-level Jarvis response flow now lives in `voice-interaction.md`.

## Endpoint

- Method: `POST`
- Path: `/v1/voice/transcriptions`
- Content type: `multipart/form-data`
- Auth: `Authorization: Bearer <token>`

## Request Fields

### Multipart Parts

- `audio_file`
  - required
  - v1 expects a WAV upload
  - iPhone client should send the finalized utterance after the user stops recording
- `client_request_id`
  - optional
  - client-generated UUID used for correlation
- `device_name`
  - optional
  - diagnostic label such as `Ben iPhone`

## Success Response

```json
{
  "request_id": "e2fd8de7-1e06-4d6c-b22d-8849b96dcad3",
  "transcript_text": "Turn on the kitchen lights",
  "normalized_text": "turn on the kitchen lights",
  "language": "en",
  "duration_ms": 1840,
  "provider": "whisper.cpp",
  "confidence": null
}
```

### Field Semantics

- `request_id`
  - server correlation ID
  - uses `client_request_id` when supplied, otherwise server-generated UUID
- `transcript_text`
  - raw recognizer output after minimal cleanup
- `normalized_text`
  - conservative normalization for downstream intent parsing
  - trim surrounding whitespace
  - collapse repeated internal whitespace
  - lowercase text
- `language`
  - v1 is English-only and returns `en`
- `duration_ms`
  - audio duration derived from the uploaded file
- `provider`
  - STT adapter identifier such as `whisper.cpp`
- `confidence`
  - nullable because not all offline adapters return a stable confidence value

## Failure Response

```json
{
  "request_id": "e2fd8de7-1e06-4d6c-b22d-8849b96dcad3",
  "error_code": "transcription_failed",
  "message": "Audio could not be transcribed."
}
```

### Failure Fields

- `request_id`
  - optional for failures that happen before request correlation is established
- `error_code`
  - stable machine-readable failure identifier
- `message`
  - user-safe explanation

## Expected Error Codes

- `unauthorized`
  - bearer token missing or invalid
- `invalid_audio`
  - empty upload or malformed WAV payload
- `unsupported_audio_format`
  - unsupported media type for v1
- `transcription_failed`
  - speech adapter failed or produced an unusable result

## Audio Retention

- Uploaded audio must be treated as ephemeral.
- Backend temp files must be deleted on both success and failure paths.
- Clients should delete their own temporary clip once the request resolves.

## Local Trace Logging

- Backend request tracing should write locally under the Jarvis repo, defaulting to `.artifacts/logs/backend/core-api.jsonl`.
- Logs are intended for local debugging and correlation.
- Logs should include request IDs, timings, status codes, provider metadata, and size/duration metadata.
- Logs must not include raw audio bytes or transcript text by default.

## Edge Cases

### Silent Audio

Silent but valid WAV uploads should return a success payload with empty transcript fields when the adapter completes successfully.

```json
{
  "request_id": "bc09d07d-15ef-4ef3-a5a8-f71042ff66d4",
  "transcript_text": "",
  "normalized_text": "",
  "language": "en",
  "duration_ms": 950,
  "provider": "whisper.cpp",
  "confidence": null
}
```

### Empty Upload

An empty file upload is invalid and must not be treated as silence.

```json
{
  "request_id": "bc09d07d-15ef-4ef3-a5a8-f71042ff66d4",
  "error_code": "invalid_audio",
  "message": "Uploaded audio file is empty."
}
```

## Compatibility Notes

- This contract is intentionally narrow for the first backend milestone.
- Future iterations may add streaming, partial transcript events, and richer metadata, but existing field meanings should remain stable.
