"""Tests for app.services.claude_client."""

from __future__ import annotations

import json
from typing import Any

import httpx
import pytest

from app.core.config import Settings
from app.core.exceptions import UpstreamError
from app.services.claude_client import ClaudeClient


def _settings(**over: Any) -> Settings:
    base: dict[str, Any] = {
        "_env_file": None,
        "ANTHROPIC_API_KEY": "test-key",
        "CLAUDE_TIMEOUT_S": 1.0,
    }
    base.update(over)
    return Settings(**base)  # type: ignore[arg-type]


def _tool_use_response(tool_input: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": "msg_abc",
        "type": "message",
        "role": "assistant",
        "content": [
            {"type": "tool_use", "id": "tu_1", "name": "submit_analysis", "input": tool_input}
        ],
        "model": "claude-sonnet-4-5-20250929",
        "stop_reason": "tool_use",
    }


def _valid_payload() -> dict[str, Any]:
    return {
        "triage_level": "NORMAL",
        "confidence": 0.91,
        "primary_concern": "No concerning signs observed.",
        "visible_symptoms": [],
        "differential": [],
        "recommended_actions": ["Continue routine monitoring."],
        "urgency_timeframe": "Routine.",
    }


async def test_happy_path_returns_tool_input() -> None:
    captured: dict[str, Any] = {}

    def handler(req: httpx.Request) -> httpx.Response:
        captured["body"] = req.read()
        captured["headers"] = dict(req.headers)
        return httpx.Response(200, json=_tool_use_response(_valid_payload()))

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as ac:
        client = ClaudeClient(_settings(), client=ac)
        out = await client.analyze("static system prompt", "user prompt")

    assert out["triage_level"] == "NORMAL"
    # Verify headers — secret in x-api-key, version pinned.
    assert captured["headers"]["x-api-key"] == "test-key"
    assert captured["headers"]["anthropic-version"] == "2023-06-01"

    # Verify body — temp 0.1, tool_choice forced, system has cache_control.
    body = json.loads(captured["body"])
    assert body["temperature"] == 0.1
    assert body["tool_choice"]["type"] == "tool"
    assert body["system"][0]["cache_control"] == {"type": "ephemeral"}


async def test_retries_once_on_5xx() -> None:
    counter = {"n": 0}

    def handler(_: httpx.Request) -> httpx.Response:
        counter["n"] += 1
        if counter["n"] == 1:
            return httpx.Response(503)
        return httpx.Response(200, json=_tool_use_response(_valid_payload()))

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as ac:
        client = ClaudeClient(_settings(), client=ac)
        out = await client.analyze("system", "user")

    assert counter["n"] == 2
    assert out["triage_level"] == "NORMAL"


async def test_no_retry_on_4xx() -> None:
    counter = {"n": 0}

    def handler(_: httpx.Request) -> httpx.Response:
        counter["n"] += 1
        return httpx.Response(401, text="auth")

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as ac:
        client = ClaudeClient(_settings(), client=ac)
        with pytest.raises(UpstreamError):
            await client.analyze("system", "user")

    assert counter["n"] == 1


async def test_response_missing_tool_block_raises() -> None:
    def handler(_: httpx.Request) -> httpx.Response:
        # Plain text content, no tool_use — should fail.
        return httpx.Response(
            200,
            json={
                "content": [{"type": "text", "text": "I cannot do this."}],
            },
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as ac:
        client = ClaudeClient(_settings(), client=ac)
        with pytest.raises(UpstreamError, match="tool_use"):
            await client.analyze("system", "user")


async def test_response_with_non_dict_input_raises() -> None:
    def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "content": [{"type": "tool_use", "name": "submit_analysis", "input": "not a dict"}],
            },
        )

    transport = httpx.MockTransport(handler)
    async with httpx.AsyncClient(transport=transport) as ac:
        client = ClaudeClient(_settings(), client=ac)
        with pytest.raises(UpstreamError, match="input is not a dict"):
            await client.analyze("system", "user")


async def test_missing_key_raises() -> None:
    settings = _settings()
    settings.anthropic_api_key = None
    transport = httpx.MockTransport(lambda r: httpx.Response(200))
    async with httpx.AsyncClient(transport=transport) as ac:
        client = ClaudeClient(settings, client=ac)
        with pytest.raises(UpstreamError, match="API key"):
            await client.analyze("system", "user")
