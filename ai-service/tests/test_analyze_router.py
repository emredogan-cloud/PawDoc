"""Integration tests for the /analyze HTTP endpoint."""

from __future__ import annotations

import os
from typing import Any

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.core.config import get_settings
from app.main import create_app
from app.models.schemas import AnalysisResult
from app.routers.analyze import get_orchestrator
from app.services.orchestrator import Orchestrator


def _result_fixture(**over: Any) -> AnalysisResult:
    base: dict[str, Any] = {
        "triage_level": "MONITOR",
        "confidence": 0.81,
        "primary_concern": "Likely mild GI upset; not immediately dangerous.",
        "visible_symptoms": ["loose stool"],
        "differential": ["dietary indiscretion"],
        "recommended_actions": ["Withhold food for 12h, then bland diet"],
        "urgency_timeframe": "Within 24 hours.",
        "model_used": "claude-sonnet-test",
        "tier_used": 3,
        "ai_latency_ms": 1234,
        "request_id": "req_test",
    }
    base.update(over)
    return AnalysisResult(**base)


class FakeOrchestrator:
    """Test double; matches Orchestrator.analyze signature."""

    def __init__(self, result: AnalysisResult) -> None:
        self._result = result
        self.calls: list[Any] = []

    async def analyze(self, request: Any) -> AnalysisResult:
        self.calls.append(request)
        return self._result.model_copy(update={"request_id": request.request_id})


def _request_body() -> dict[str, Any]:
    return {
        "request_id": "req_abc",
        "pet": {
            "pet_id": "11111111-1111-1111-1111-111111111111",
            "name": "Luna",
            "species": "dog",
        },
        "input_type": "text",
        "text_description": "She has been quiet today.",
    }


@pytest.fixture
def app_with_fake() -> tuple[FastAPI, FakeOrchestrator]:
    """Build an app with the orchestrator + settings overridden."""
    get_settings.cache_clear()
    # set the token via env so the verifier finds it.
    os.environ["INTERNAL_API_TOKEN"] = "secret-token"

    app = create_app()
    fake = FakeOrchestrator(_result_fixture())

    def _fake_orchestrator() -> Any:
        return fake

    app.dependency_overrides[get_orchestrator] = _fake_orchestrator
    return app, fake


async def test_rejects_request_without_internal_token(
    app_with_fake: tuple[FastAPI, FakeOrchestrator],
) -> None:
    app, _ = app_with_fake
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as ac:
        resp = await ac.post("/analyze", json=_request_body())
    assert resp.status_code == 401


async def test_rejects_wrong_internal_token(
    app_with_fake: tuple[FastAPI, FakeOrchestrator],
) -> None:
    app, _ = app_with_fake
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as ac:
        resp = await ac.post(
            "/analyze",
            json=_request_body(),
            headers={"X-PawDoc-Internal-Token": "wrong"},
        )
    assert resp.status_code == 401


async def test_accepts_correct_token_and_returns_result(
    app_with_fake: tuple[FastAPI, FakeOrchestrator],
) -> None:
    app, fake = app_with_fake
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as ac:
        resp = await ac.post(
            "/analyze",
            json=_request_body(),
            headers={
                "X-PawDoc-Internal-Token": "secret-token",
                "X-Request-ID": "req_xyz",
            },
        )
    assert resp.status_code == 200
    body = resp.json()
    assert body["triage_level"] == "MONITOR"
    assert body["tier_used"] == 3
    # request_id propagates: header overrides body? The router uses the
    # header preferentially, but binds whichever is provided to the result.
    assert body["request_id"] in {"req_xyz", "req_abc"}
    assert len(fake.calls) == 1


async def test_rejects_malformed_body(
    app_with_fake: tuple[FastAPI, FakeOrchestrator],
) -> None:
    app, _ = app_with_fake
    bad = _request_body()
    bad["input_type"] = "audio"  # not in enum
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as ac:
        resp = await ac.post(
            "/analyze",
            json=bad,
            headers={"X-PawDoc-Internal-Token": "secret-token"},
        )
    assert resp.status_code == 422


async def test_service_unconfigured_returns_503(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("INTERNAL_API_TOKEN", raising=False)
    get_settings.cache_clear()
    app = create_app()

    fake = FakeOrchestrator(_result_fixture())
    app.dependency_overrides[get_orchestrator] = lambda: fake

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://t") as ac:
        resp = await ac.post(
            "/analyze",
            json=_request_body(),
            headers={"X-PawDoc-Internal-Token": "anything"},
        )
    assert resp.status_code == 503


def test_orchestrator_dependency_constructs() -> None:
    """Sanity: get_orchestrator() builds without crashing in a happy env."""
    os.environ["INTERNAL_API_TOKEN"] = "x"
    os.environ["ANTHROPIC_API_KEY"] = "x"
    os.environ["GOOGLE_AI_API_KEY"] = "x"
    get_settings.cache_clear()
    orch = get_orchestrator(get_settings())
    assert isinstance(orch, Orchestrator)
