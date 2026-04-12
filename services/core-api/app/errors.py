from __future__ import annotations

from fastapi.responses import JSONResponse

from .schemas import ErrorResponse
from .telemetry import set_error_code, set_request_id


class ApiError(Exception):
    def __init__(
        self,
        *,
        status_code: int,
        error_code: str,
        message: str,
        request_id: str | None = None,
    ) -> None:
        self.status_code = status_code
        self.error_code = error_code
        self.message = message
        self.request_id = request_id
        super().__init__(message)


def build_error_response(
    *,
    status_code: int,
    error_code: str,
    message: str,
    request_id: str | None = None,
) -> JSONResponse:
    set_error_code(error_code)
    if request_id is not None:
        set_request_id(request_id)

    return JSONResponse(
        status_code=status_code,
        content=ErrorResponse(
            request_id=request_id,
            error_code=error_code,
            message=message,
        ).model_dump(exclude_none=True),
    )
