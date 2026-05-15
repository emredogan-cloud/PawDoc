"""Tests for the /health endpoint."""

from __future__ import annotations

from datetime import datetime

from httpx import AsyncClient

from app import __version__


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
