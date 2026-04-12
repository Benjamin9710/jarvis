from __future__ import annotations

from contextlib import contextmanager
from contextvars import ContextVar, Token
from dataclasses import dataclass, field
from datetime import datetime, timezone
import json
from pathlib import Path
import threading
import time
from typing import Any, Iterator
import uuid


@dataclass(slots=True)
class TraceState:
    request_id: str
    root_span_id: str
    current_span_id: str
    error_code: str | None = None


@dataclass(slots=True)
class TraceSpan:
    name: str
    span_id: str
    parent_span_id: str | None
    attributes: dict[str, Any] = field(default_factory=dict)

    def set_attribute(self, key: str, value: Any) -> None:
        self.attributes[key] = value


class LocalTraceLogger:
    def __init__(
        self,
        directory: Path,
        *,
        service_name: str = "core-api",
        file_name: str = "core-api.jsonl",
    ) -> None:
        self._directory = directory
        self._service_name = service_name
        self._path = directory / file_name
        self._lock = threading.Lock()

    @property
    def path(self) -> Path:
        return self._path

    def write(self, *, state: TraceState, span: TraceSpan, duration_ms: int, status_code: int | None = None) -> None:
        self._directory.mkdir(parents=True, exist_ok=True)

        payload: dict[str, Any] = {
            "timestamp": datetime.now(tz=timezone.utc).isoformat(),
            "service_name": self._service_name,
            "event_name": span.name,
            "request_id": state.request_id,
            "span_id": span.span_id,
            "parent_span_id": span.parent_span_id,
            "duration_ms": duration_ms,
            "attributes": span.attributes,
        }
        if state.error_code is not None:
            payload["error_code"] = state.error_code
        if status_code is not None:
            payload["status_code"] = status_code

        with self._lock:
            with self._path.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(payload, sort_keys=True))
                handle.write("\n")


_trace_logger: LocalTraceLogger | None = None
_trace_state: ContextVar[TraceState | None] = ContextVar("jarvis_trace_state", default=None)


def configure_trace_logger(logger: LocalTraceLogger) -> None:
    global _trace_logger
    _trace_logger = logger


def current_request_id() -> str | None:
    state = _trace_state.get()
    return state.request_id if state is not None else None


def begin_request_trace() -> Token[TraceState | None]:
    trace_state = TraceState(
        request_id=str(uuid.uuid4()),
        root_span_id=uuid.uuid4().hex,
        current_span_id="",
    )
    trace_state.current_span_id = trace_state.root_span_id
    return _trace_state.set(trace_state)


def end_request_trace(token: Token[TraceState | None]) -> None:
    _trace_state.reset(token)


def set_request_id(request_id: str) -> None:
    state = _trace_state.get()
    if state is not None:
        state.request_id = request_id


def set_error_code(error_code: str) -> None:
    state = _trace_state.get()
    if state is not None:
        state.error_code = error_code


def log_request_completion(*, method: str, path: str, status_code: int, duration_ms: int) -> None:
    state = _trace_state.get()
    if state is None or _trace_logger is None:
        return

    _trace_logger.write(
        state=state,
        span=TraceSpan(
            name="http.request",
            span_id=state.root_span_id,
            parent_span_id=None,
            attributes={
                "http_method": method,
                "http_path": path,
            },
        ),
        duration_ms=duration_ms,
        status_code=status_code,
    )


@contextmanager
def start_span(name: str, **attributes: Any) -> Iterator[TraceSpan]:
    state = _trace_state.get()
    if state is None or _trace_logger is None:
        yield TraceSpan(name=name, span_id="", parent_span_id=None, attributes=dict(attributes))
        return

    previous_span_id = state.current_span_id
    span = TraceSpan(
        name=name,
        span_id=uuid.uuid4().hex,
        parent_span_id=previous_span_id,
        attributes=dict(attributes),
    )
    state.current_span_id = span.span_id
    started_at = time.perf_counter()

    try:
        yield span
    except Exception as error:
        span.set_attribute("exception_type", error.__class__.__name__)
        raise
    finally:
        duration_ms = int((time.perf_counter() - started_at) * 1000)
        _trace_logger.write(state=state, span=span, duration_ms=duration_ms)
        state.current_span_id = previous_span_id
