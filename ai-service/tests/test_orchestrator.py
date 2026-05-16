"""Tests for app.services.orchestrator — routing + safety + retry.

The orchestrator is the most consequential code path; we mock the provider
clients (which have their own dedicated tests) and exercise routing
exhaustively.
"""

from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

import pytest

from app.core.config import Settings
from app.core.exceptions import UpstreamError
from app.models.schemas import AnalysisRequest, PetContext
from app.services.orchestrator import Orchestrator


def _settings(**over: Any) -> Settings:
    base: dict[str, Any] = {
        "_env_file": None,
        "ANTHROPIC_API_KEY": "k",
        "GOOGLE_AI_API_KEY": "k",
        "TIER2_CONFIDENCE_FLOOR": 0.85,
        "INSUFFICIENT_CONFIDENCE_FLOOR": 0.60,
    }
    base.update(over)
    return Settings(**base)  # type: ignore[arg-type]


def _request(text: str | None = None, breed: str | None = None) -> AnalysisRequest:
    return AnalysisRequest(
        request_id="req_test",
        pet=PetContext(pet_id="p1", name="Luna", species="dog", breed=breed),
        input_type="text",
        text_description=text,
    )


def _provider_payload(
    triage: str = "MONITOR",
    confidence: float = 0.80,
    primary: str = "Some plausible concern that is long enough.",
) -> dict[str, Any]:
    return {
        "triage_level": triage,
        "confidence": confidence,
        "primary_concern": primary,
        "visible_symptoms": ["sym"],
        "differential": ["alt"],
        "recommended_actions": ["See a vet within 24h"],
        "urgency_timeframe": "Within 24 hours.",
    }


# ---- Fake provider clients ------------------------------------------------


@dataclass
class FakeGemini:
    """Calls a per-test-supplied factory to produce raw JSON or raise."""

    responder: Callable[[int], object]
    calls: list[tuple[str, str]] = field(default_factory=list)

    async def analyze(self, system_prompt: str, user_prompt: str) -> str:
        self.calls.append((system_prompt, user_prompt))
        out = self.responder(len(self.calls))
        if isinstance(out, BaseException):
            raise out
        return out if isinstance(out, str) else json.dumps(out)


@dataclass
class FakeClaude:
    responder: Callable[[int], object]
    calls: list[tuple[str, str]] = field(default_factory=list)

    async def analyze(self, system_prompt: str, user_prompt: str) -> dict[str, Any]:
        self.calls.append((system_prompt, user_prompt))
        out = self.responder(len(self.calls))
        if isinstance(out, BaseException):
            raise out
        return out  # type: ignore[return-value]


# ---- Tests -----------------------------------------------------------------


async def test_emergency_keyword_short_circuits_all_ai_calls() -> None:
    gem_calls = 0
    claude_calls = 0

    def gem(_n: int) -> Any:
        nonlocal gem_calls
        gem_calls += 1
        return _provider_payload()

    def claude(_n: int) -> Any:
        nonlocal claude_calls
        claude_calls += 1
        return _provider_payload()

    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(gem),
        claude=FakeClaude(claude),
    )
    result = await orchestrator.analyze(_request(text="My dog had a seizure"))

    assert result.triage_level == "EMERGENCY"
    assert result.tier_used == 1
    assert result.emergency_override_applied is True
    assert gem_calls == 0
    assert claude_calls == 0


async def test_tier2_resolves_at_high_confidence() -> None:
    payload = _provider_payload(triage="NORMAL", confidence=0.92)
    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(lambda _n: payload),
        claude=FakeClaude(lambda _n: pytest.fail("Claude should not be called")),
    )
    result = await orchestrator.analyze(_request(text="She's been eating well"))
    assert result.tier_used == 2
    assert result.triage_level == "NORMAL"


async def test_tier2_low_confidence_escalates_to_tier3() -> None:
    g_payload = _provider_payload(triage="MONITOR", confidence=0.55)
    c_payload = _provider_payload(triage="MONITOR", confidence=0.82)
    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(lambda _n: g_payload),
        claude=FakeClaude(lambda _n: c_payload),
    )
    result = await orchestrator.analyze(_request(text="ear redness"))
    assert result.tier_used == 3
    assert result.confidence == 0.82


async def test_tier2_emergency_always_escalates_to_tier3_then_cross_verify() -> None:
    g_payload = _provider_payload(triage="EMERGENCY", confidence=0.95)
    c_payload = _provider_payload(triage="EMERGENCY", confidence=0.90)
    claude_call_count = 0

    def claude(_n: int) -> Any:
        nonlocal claude_call_count
        claude_call_count += 1
        return c_payload

    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(lambda _n: g_payload),
        claude=FakeClaude(claude),
    )
    result = await orchestrator.analyze(_request(text="something off"))
    assert result.tier_used == 3
    assert result.triage_level == "EMERGENCY"
    assert claude_call_count == 2  # first analysis + cross-verify


async def test_cross_verify_disagreement_downgrades_to_monitor() -> None:
    g_payload = _provider_payload(triage="MONITOR", confidence=0.50)
    c_payload_1 = _provider_payload(triage="EMERGENCY", confidence=0.80)
    c_payload_2 = _provider_payload(triage="MONITOR", confidence=0.75)

    def claude(n: int) -> Any:
        return c_payload_1 if n == 1 else c_payload_2

    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(lambda _n: g_payload),
        claude=FakeClaude(claude),
    )
    result = await orchestrator.analyze(_request(text="lethargic"))
    assert result.triage_level == "MONITOR"
    assert result.cross_verify_disagreement is True


async def test_tier3_below_confidence_floor_returns_graceful() -> None:
    g_payload = _provider_payload(triage="MONITOR", confidence=0.50)
    c_payload = _provider_payload(triage="NORMAL", confidence=0.40)
    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(lambda _n: g_payload),
        claude=FakeClaude(lambda _n: c_payload),
    )
    result = await orchestrator.analyze(_request(text="something"))
    assert result.tier_used == 0  # graceful sentinel
    assert result.triage_level == "MONITOR"
    assert result.confidence == 0.0


async def test_tier3_provider_failure_returns_graceful() -> None:
    g_payload = _provider_payload(triage="MONITOR", confidence=0.50)

    def claude(_n: int) -> Any:
        return UpstreamError("claude down")

    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(lambda _n: g_payload),
        claude=FakeClaude(claude),
    )
    result = await orchestrator.analyze(_request(text="symptoms"))
    assert result.tier_used == 0
    assert result.model_used == "graceful_degradation"


async def test_gemini_failure_escalates_to_tier3() -> None:
    """If Gemini blows up, we still try Claude."""

    def gem(_n: int) -> Any:
        return UpstreamError("gemini down")

    c_payload = _provider_payload(triage="NORMAL", confidence=0.85)
    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(gem),
        claude=FakeClaude(lambda _n: c_payload),
    )
    result = await orchestrator.analyze(_request(text="symptoms"))
    assert result.tier_used == 3
    assert result.triage_level == "NORMAL"


async def test_parser_failure_retries_with_hint_then_succeeds() -> None:
    """First Gemini response is malformed; retry with hint succeeds."""
    payloads = [
        "{not json",
        _provider_payload(triage="MONITOR", confidence=0.92),
    ]

    def gem(n: int) -> Any:
        return payloads[n - 1]

    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(gem),
        claude=FakeClaude(lambda _n: pytest.fail("Claude should not be called")),
    )
    result = await orchestrator.analyze(_request(text="something"))
    assert result.tier_used == 2
    assert result.confidence == 0.92


async def test_parser_failure_twice_escalates_to_tier3() -> None:
    """Both Gemini attempts fail → escalate to Claude."""

    def gem(_n: int) -> Any:
        return "still not json"

    c_payload = _provider_payload(triage="MONITOR", confidence=0.78)
    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(gem),
        claude=FakeClaude(lambda _n: c_payload),
    )
    result = await orchestrator.analyze(_request(text="x"))
    assert result.tier_used == 3


async def test_result_has_ai_latency_ms_set() -> None:
    payload = _provider_payload(triage="NORMAL", confidence=0.92)
    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(lambda _n: payload),
        claude=FakeClaude(lambda _n: pytest.fail("not called")),
    )
    result = await orchestrator.analyze(_request(text="hi"))
    assert result.ai_latency_ms >= 0
    assert result.request_id == "req_test"
