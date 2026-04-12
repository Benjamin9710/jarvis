from pathlib import Path

import pytest

from jarvis_voice import AudioUpload, FakeSpeechToTextAdapter, UnsupportedAudioFormatError, VoiceTranscriptionService


def test_transcribe_upload_returns_completed_transcription(tmp_path: Path) -> None:
    fixture_path = Path(__file__).parent / "fixtures" / "silence-1s.wav"
    service = VoiceTranscriptionService(
        adapter=FakeSpeechToTextAdapter(transcript_text="Turn   On The Kitchen Lights"),
        temp_dir=tmp_path,
    )

    result = service.transcribe_upload(
        AudioUpload(
            filename="sample.wav",
            data=fixture_path.read_bytes(),
            content_type="audio/wav",
        ),
        request_id="test-request",
    )

    assert result.request_id == "test-request"
    assert result.transcript_text == "Turn   On The Kitchen Lights"
    assert result.normalized_text == "turn on the kitchen lights"
    assert result.duration_ms == 1000
    assert not list(tmp_path.iterdir())


def test_transcribe_upload_rejects_invalid_wav(tmp_path: Path) -> None:
    service = VoiceTranscriptionService(adapter=FakeSpeechToTextAdapter(), temp_dir=tmp_path)

    with pytest.raises(UnsupportedAudioFormatError):
        service.transcribe_upload(
            AudioUpload(
                filename="sample.wav",
                data=b"not-a-wav",
                content_type="audio/wav",
            )
        )
