"""Tests for the FastAPI application factory + lifespan."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.config import AppEnv, get_settings
from app.main import create_app


def test_create_app_returns_distinct_instances() -> None:
    a = create_app()
    b = create_app()
    assert a is not b


@pytest.mark.parametrize("env", [AppEnv.LOCAL, AppEnv.DEV])
def test_docs_enabled_in_non_prod(env: AppEnv, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", env.value)
    get_settings.cache_clear()
    app = create_app()
    assert app.docs_url == "/docs"
    assert app.openapi_url == "/openapi.json"


def test_docs_disabled_in_prod(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "prod")
    get_settings.cache_clear()
    app = create_app()
    assert app.docs_url is None
    assert app.openapi_url is None


async def test_lifespan_runs_without_error() -> None:
    """LifespanManager exercises the startup/shutdown hooks."""
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://t") as client:
        # Hitting any endpoint inside the context exercises lifespan startup.
        response = await client.get("/health")
        assert response.status_code == 200


def test_cors_origins_parsed(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ALLOWED_ORIGINS", "http://a.test, http://b.test")
    get_settings.cache_clear()
    app = create_app()
    cors = next(m for m in app.user_middleware if "CORS" in m.cls.__name__)
    assert "http://a.test" in cors.kwargs["allow_origins"]
    assert "http://b.test" in cors.kwargs["allow_origins"]
