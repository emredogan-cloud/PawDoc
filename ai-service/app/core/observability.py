"""Observability helpers — request id propagation + latency tracking.

The edge function generates an ``X-Request-ID`` and forwards it to the AI
service. We bind it to structlog's contextvars so every log line emitted
during the request includes it. ``Timer`` is a small context manager that
records milliseconds for per-stage latency tracking.
"""

from __future__ import annotations

import time
from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import ContextVar

import structlog

# ContextVar so async hops don't lose the binding.
_request_id: ContextVar[str | None] = ContextVar("pawdoc_request_id", default=None)


def bind_request_id(request_id: str) -> None:
    """Bind the request id to the structlog context for this async task."""
    _request_id.set(request_id)
    structlog.contextvars.bind_contextvars(request_id=request_id)


def clear_request_context() -> None:
    """Reset the request-scoped context. Call at request end."""
    _request_id.set(None)
    structlog.contextvars.clear_contextvars()


def current_request_id() -> str | None:
    return _request_id.get()


@contextmanager
def Timer(label: str, log: structlog.stdlib.BoundLogger | None = None) -> Iterator[TimerHandle]:
    """Time a code block; logs duration on exit (info or warning).

    Use::

        with Timer("gemini_call", log) as t:
            await gemini_client.analyze(...)
        latency_ms = t.elapsed_ms
    """
    handle = TimerHandle(label)
    handle._start = time.monotonic()
    try:
        yield handle
    finally:
        handle._stop = time.monotonic()
        if log is not None:
            log.info(
                "stage_timing",
                stage=label,
                latency_ms=handle.elapsed_ms,
            )


class TimerHandle:
    """Mutable handle yielded by ``Timer`` — exposes elapsed time."""

    __slots__ = ("_label", "_start", "_stop")

    def __init__(self, label: str) -> None:
        self._label = label
        self._start = 0.0
        self._stop = 0.0

    @property
    def elapsed_ms(self) -> int:
        end = self._stop if self._stop > 0 else time.monotonic()
        return max(0, int((end - self._start) * 1000))
