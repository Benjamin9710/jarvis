import re


_WHITESPACE_PATTERN = re.compile(r"\s+")


def normalize_transcript(transcript_text: str) -> str:
    collapsed = _WHITESPACE_PATTERN.sub(" ", transcript_text).strip()
    return collapsed.lower()
