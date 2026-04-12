from __future__ import annotations

from fastapi import Depends, Header

from .config import Settings
from .dependencies import get_settings
from .errors import ApiError
from .telemetry import start_span


def verify_bearer_token(
    authorization: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> None:
    with start_span("auth.verify_bearer_token") as span:
        expected_token = settings.api_bearer_token
        span.set_attribute("authorization_present", authorization is not None)

        if not authorization:
            raise ApiError(
                status_code=401,
                error_code="unauthorized",
                message="Missing bearer token.",
            )

        scheme, _, credentials = authorization.partition(" ")
        span.set_attribute("authorization_scheme", scheme.lower())
        if scheme.lower() != "bearer" or not credentials.strip():
            raise ApiError(
                status_code=401,
                error_code="unauthorized",
                message="Missing bearer token.",
            )

        provided_token = credentials.strip()
        if provided_token != expected_token:
            raise ApiError(
                status_code=401,
                error_code="unauthorized",
                message="Invalid bearer token.",
            )
