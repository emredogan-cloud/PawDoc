"""Tests for the /health and /ready endpoints."""

from __future__ import annotations

from datetime import datetime

import pytest
from httpx import AsyncClient

from app import __version__
from app.core.config import get_settings


async def test_health_returns_200(client: AsyncClient) -> None:
    response = await client.get("/health")
    assert response.status_code == 200


async def test_health_payload_shape(client: AsyncClient) -> None:
    response = await client.get("/health")
    body = response.json()
    assert body["status"] == "ok"
    assert body["service"] == "pawdoc-ai"
    assert body["version"] == __version__
    assert body["environment"] in {"local", "dev", "prod"}
    # Roundtrip the timestamp through datetime to assert it's ISO-8601.
    datetime.fromisoformat(body["timestamp"])


async def test_health_rejects_post(client: AsyncClient) -> None:
    response = await client.post("/health")
    assert response.status_code == 405


# ---------------------------------------------------------------------------
# Sprint B3 (F-OPS3) — /ready
# ---------------------------------------------------------------------------


async def test_ready_returns_200_in_local(client: AsyncClient) -> None:
    """LOCAL env is intentionally lenient — a developer without
    .env wired up should still see 200 from the readiness probe."""
    response = await client.get("/ready")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["service"] == "pawdoc-ai"
    assert body["environment"] == "local"


async def test_ready_returns_200_when_all_keys_set(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Validate the dev branch: all required keys present → 200."""
    monkeypatch.setenv("APP_ENV", "dev")
    monkeypatch.setenv("INTERNAL_API_TOKEN", "tok")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "anth")
    monkeypatch.setenv("GOOGLE_AI_API_KEY", "goog")
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "srv")
    # `app` fixture built `Settings()` BEFORE monkeypatch ran — flush
    # so the handler sees fresh env.
    get_settings.cache_clear()

    response = await client.get("/ready")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["missing"] == []


async def test_ready_returns_503_when_keys_missing_in_dev(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Dev with no secrets reports degraded so monitors page the operator."""
    monkeypatch.setenv("APP_ENV", "dev")
    get_settings.cache_clear()
    response = await client.get("/ready")
    assert response.status_code == 503
    body = response.json()
    assert body["status"] == "degraded"
    assert "INTERNAL_API_TOKEN" in body["missing"]
    assert "ANTHROPIC_API_KEY" in body["missing"]
    assert "GOOGLE_AI_API_KEY" in body["missing"]
    assert "SUPABASE_URL" in body["missing"]
    assert "SUPABASE_SERVICE_ROLE_KEY" in body["missing"]


async def test_ready_lists_only_missing_key(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("APP_ENV", "dev")
    monkeypatch.setenv("INTERNAL_API_TOKEN", "tok")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "anth")
    monkeypatch.setenv("GOOGLE_AI_API_KEY", "goog")
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    # SUPABASE_SERVICE_ROLE_KEY deliberately absent.
    get_settings.cache_clear()
    response = await client.get("/ready")
    assert response.status_code == 503
    body = response.json()
    assert body["missing"] == ["SUPABASE_SERVICE_ROLE_KEY"]


async def test_ready_rejects_post(client: AsyncClient) -> None:
    response = await client.post("/ready")
    assert response.status_code == 405
