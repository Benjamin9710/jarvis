from jarvis_voice.normalization import normalize_transcript


def test_normalize_transcript_collapses_whitespace_and_lowercases() -> None:
    assert normalize_transcript("  Turn   On   The Kitchen Lights  ") == "turn on the kitchen lights"


def test_normalize_transcript_preserves_empty_text() -> None:
    assert normalize_transcript("   ") == ""
