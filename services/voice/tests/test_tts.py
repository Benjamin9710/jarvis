from jarvis_voice import FakeTextToSpeechAdapter, JarvisResponseComposer, TextToSpeechRequest, TextToSpeechService


def test_fake_tts_returns_wav_bytes() -> None:
    service = TextToSpeechService(adapter=FakeTextToSpeechAdapter())

    result = service.synthesize(TextToSpeechRequest(text="Certainly. The kitchen lights are now on."))

    assert result.provider == "fake-tts"
    assert result.content_type == "audio/wav"
    assert result.sample_rate_hz == 24_000
    assert result.audio_bytes.startswith(b"RIFF")


def test_jarvis_response_composer_formats_success_and_unsupported() -> None:
    composer = JarvisResponseComposer()

    turn_on = composer.compose_success("turn_on", "kitchen")
    unsupported = composer.compose_unsupported()

    assert turn_on.summary_text == "Kitchen lights turned on"
    assert turn_on.spoken_text == "Certainly. The kitchen lights are now on."
    assert unsupported.summary_text == "Command not available"
    assert unsupported.spoken_text == "I'm afraid I can't do that just yet."
