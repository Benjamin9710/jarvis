class TranscriptionError(Exception):
    def __init__(self, error_code: str, message: str, status_code: int = 400) -> None:
        super().__init__(message)
        self.error_code = error_code
        self.message = message
        self.status_code = status_code


class InvalidAudioError(TranscriptionError):
    def __init__(self, message: str = "Uploaded audio file is empty.") -> None:
        super().__init__("invalid_audio", message, status_code=400)


class UnsupportedAudioFormatError(TranscriptionError):
    def __init__(self, message: str = "Uploaded audio must be a valid WAV file.") -> None:
        super().__init__("unsupported_audio_format", message, status_code=415)


class AdapterExecutionError(TranscriptionError):
    def __init__(self, message: str = "Audio could not be transcribed.") -> None:
        super().__init__("transcription_failed", message, status_code=500)
