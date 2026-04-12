from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import time

from .config import Settings
from .dependencies import build_transcription_service
from .errors import ApiError, build_error_response
from .routes.health import router as health_router
from .routes.voice import router as voice_router
from .telemetry import (
    LocalTraceLogger,
    begin_request_trace,
    configure_trace_logger,
    end_request_trace,
    log_request_completion,
)


def create_app(
    settings: Settings | None = None,
) -> FastAPI:
    resolved_settings = settings or Settings()

    app = FastAPI(title="Jarvis Core API")
    app.state.settings = resolved_settings
    app.state.transcription_service = build_transcription_service(resolved_settings)
    app.state.trace_logger = LocalTraceLogger(directory=resolved_settings.backend_log_dir)
    configure_trace_logger(app.state.trace_logger)

    @app.middleware("http")
    async def trace_requests(request: Request, call_next):
        token = begin_request_trace()
        started_at = time.perf_counter()
        status_code = 500

        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        finally:
            duration_ms = int((time.perf_counter() - started_at) * 1000)
            log_request_completion(
                method=request.method,
                path=request.url.path,
                status_code=status_code,
                duration_ms=duration_ms,
            )
            end_request_trace(token)

    @app.exception_handler(ApiError)
    async def handle_api_error(
        _request: Request,
        exc: ApiError,
    ) -> JSONResponse:
        return build_error_response(
            status_code=exc.status_code,
            error_code=exc.error_code,
            message=exc.message,
            request_id=exc.request_id,
        )

    app.include_router(health_router)
    app.include_router(voice_router)

    return app


app = create_app()
