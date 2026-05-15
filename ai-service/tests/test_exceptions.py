"""Tests for app.core.exceptions handlers."""

from __future__ import annotations

from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.core.exceptions import (
    PawDocError,
    UpstreamError,
    ValidationError,
    register_exception_handlers,
)


def test_pawdoc_error_default_attrs() -> None:
    err = PawDocError("boom")
    assert err.status_code == 500
    assert err.error_code == "internal_error"
    assert err.to_response() == {"error": "internal_error", "message": "boom"}


def test_pawdoc_error_override_error_code() -> None:
    err = PawDocError("bad input", error_code="invalid_user")
    assert err.to_response()["error"] == "invalid_user"


def test_validation_error_subclass() -> None:
    err = ValidationError("missing field")
    assert err.status_code == 422
    assert err.error_code == "validation_error"


def test_upstream_error_subclass() -> None:
    err = UpstreamError("anthropic 503")
    assert err.status_code == 502
    assert err.error_code == "upstream_error"


async def test_handler_returns_structured_response() -> None:
    app = FastAPI()
    register_exception_handlers(app)

    @app.get("/boom")
    async def boom() -> None:
        raise UpstreamError("test upstream failure")

    @app.get("/kaboom")
    async def kaboom() -> None:
        raise RuntimeError("unexpected")

    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://t") as client:
        r1 = await client.get("/boom")
        assert r1.status_code == 502
        assert r1.json() == {"error": "upstream_error", "message": "test upstream failure"}

        r2 = await client.get("/kaboom")
        assert r2.status_code == 500
        assert r2.json()["error"] == "internal_error"
        # Generic catch-all returns a SAFE generic message — must not echo the
        # raw exception's str (would risk leaking internals).
        assert r2.json()["message"] == "An unexpected error occurred."
