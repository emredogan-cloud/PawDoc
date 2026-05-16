"""Tests for app.services.gemini_client."""

from __future__ import annotations

import json
from typing import Any

import httpx
import pytest

from app.core.config import Settings
from app.core.exceptions import UpstreamError
from app.models.schemas import AnalysisRequest, PetContext
from app.services.gemini_client import GeminiClient, build_user_prompt


def _settings(**over: Any) -> Settings:
    base: dict[str, Any] = {
        "_env_file": None,
        "GOOGLE_AI_API_KEY": "test-key",
        "GEMINI_TIMEOUT_S": 1.0,
    }
    base.update(over)
    return Settings(**base)  # type: ignore[arg-type]


def _request() -> AnalysisRequest:
    return AnalysisRequest(
        request_id="req_abc",
        pet=PetContext(pet_id="p1", name="Luna", species="dog", breed="Golden Retriever"),
        input_type="text",
        text_description="She has been limping today.",
    )


def _gemini_response(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "candidates": [
            {
                "content": {"parts": [{"text": json.dumps(payload)}]},
            }
        ]
    }


def _valid_provider_payload() -> dict[str, Any]:
    return {
        "triage_level": "MONITOR",
        "confidence": 0.78,
        "primary_concern": "Possible soft-tissue injury in the left front leg.",
        "visible_symptoms": [],
        "differential": ["soft-tissue strain"],
        "recommended_actions": ["Restrict activity for 48h", "Vet visit if not improving"],
        "urgency_timeframe": "Within 48 hours.",
    }


async def test_happy_path_returns_text() -> None:
    def handler(req: httpx.Request) -> httpx.Response:
        assert "generateContent" in req.url.path
        # The API key should be in the query, not headers.
        assert req.url.params.get("key") == "test-key"
        return httpx.Response(200, json=_gemini_response(_valid_provider_payload()))

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as ac:
        client = GeminiClient(_settings(), client=ac)
        text = await client.analyze("system", "user")

    data = json.loads(text)
    assert data["triage_level"] == "MONITOR"


async def test_retries_once_on_5xx() -> None:
    calls = {"count": 0}

    def handler(req: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        if calls["count"] == 1:
            return httpx.Response(503, text="boom")
        return httpx.Response(200, json=_gemini_response(_valid_provider_payload()))

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as ac:
        client = GeminiClient(_settings(), client=ac)
        text = await client.analyze("system", "user")

    assert calls["count"] == 2
    assert "MONITOR" in text


async def test_no_retry_on_4xx() -> None:
    calls = {"count": 0}

    def handler(req: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        return httpx.Response(401, text="bad key")

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as ac:
        client = GeminiClient(_settings(), client=ac)
        with pytest.raises(UpstreamError):
            await client.analyze("system", "user")

    assert calls["count"] == 1


async def test_request_error_retries_once() -> None:
    calls = {"count": 0}

    def handler(req: httpx.Request) -> httpx.Response:
        calls["count"] += 1
        raise httpx.ConnectTimeout("timeout")

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as ac:
        client = GeminiClient(_settings(), client=ac)
        with pytest.raises(UpstreamError):
            await client.analyze("system", "user")

    assert calls["count"] == 2


async def test_missing_key_raises_upstream_error() -> None:
    settings = _settings()
    settings.google_ai_api_key = None
    transport = httpx.MockTransport(lambda r: httpx.Response(200))
    async with httpx.AsyncClient(transport=transport) as ac:
        client = GeminiClient(settings, client=ac)
        with pytest.raises(UpstreamError, match="API key"):
            await client.analyze("system", "user")


def test_build_user_prompt_includes_breed_context_when_provided() -> None:
    out = build_user_prompt(_request(), breed_context="Bulldogs are brachycephalic ...")
    assert "Bulldogs are brachycephalic" in out
    assert "Golden Retriever" in out
    assert "limping today" in out


def test_build_user_prompt_omits_breed_block_when_empty() -> None:
    out = build_user_prompt(_request(), breed_context="")
    assert "Breed risk context" not in out


async def test_response_with_missing_text_raises() -> None:
    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"candidates": [{"content": {"parts": []}}]})

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as ac:
        client = GeminiClient(_settings(), client=ac)
        with pytest.raises(UpstreamError):
            await client.analyze("system", "user")
