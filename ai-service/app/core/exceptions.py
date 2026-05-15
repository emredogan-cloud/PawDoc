"""Typed exception hierarchy and FastAPI exception handlers.

Phase 0 ships the shape; Phase 1 fills in concrete subclasses (e.g., upstream
provider failures, schema-validation errors, safety-override failures).
"""

from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.core.logging import get_logger

log = get_logger(__name__)


class PawDocError(Exception):
    """Base class for all application-level errors.

    Use subclasses, not this class directly — callers should never have to
    guard against the bare base.
    """

    status_code: int = 500
    error_code: str = "internal_error"

    def __init__(self, message: str, *, error_code: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        if error_code is not None:
            self.error_code = error_code

    def to_response(self) -> dict[str, str]:
        return {"error": self.error_code, "message": self.message}


class ValidationError(PawDocError):
    status_code = 422
    error_code = "validation_error"


class UpstreamError(PawDocError):
    """Failure from an external provider (Anthropic, Gemini, Supabase, R2)."""

    status_code = 502
    error_code = "upstream_error"


def register_exception_handlers(app: FastAPI) -> None:
    """Attach handlers so every error becomes a structured JSON response.

    The handler MUST NOT echo back raw exception messages from upstream
    providers without sanitisation — that's a future Phase 1 concern, but this
    file is the seam where it'll happen.
    """

    @app.exception_handler(PawDocError)
    async def _pawdoc_error_handler(_: Request, exc: PawDocError) -> JSONResponse:
        log.warning(
            "pawdoc_error",
            error_code=exc.error_code,
            status_code=exc.status_code,
            message=exc.message,
        )
        return JSONResponse(status_code=exc.status_code, content=exc.to_response())

    @app.exception_handler(Exception)
    async def _unhandled_handler(_: Request, exc: Exception) -> JSONResponse:
        log.exception("unhandled_exception", exc_type=type(exc).__name__)
        return JSONResponse(
            status_code=500,
            content={"error": "internal_error", "message": "An unexpected error occurred."},
        )
