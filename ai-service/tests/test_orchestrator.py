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


# ---------------------------------------------------------------------------
# Sprint B3 (F-OPS7) — provider-degradation chaos coverage
# ---------------------------------------------------------------------------


async def test_both_providers_fail_returns_graceful_degradation() -> None:
    """Tier 2 transport error AND Tier 3 transport error → graceful
    fallback. This is the worst-case "the internet ate our AI providers"
    scenario; user must still see a coherent result, not a 500."""

    def gem(_n: int) -> Any:
        return UpstreamError("gemini down")

    def claude(_n: int) -> Any:
        return UpstreamError("claude down")

    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(gem),
        claude=FakeClaude(claude),
    )
    result = await orchestrator.analyze(_request(text="symptoms"))
    assert result.tier_used == 0
    assert result.triage_level == "MONITOR"
    assert result.model_used == "graceful_degradation"
    assert result.confidence == 0.0


async def test_graceful_degradation_uses_centralised_copy() -> None:
    """The orchestrator's graceful path must use the B3 copy module —
    a refactor that hardcodes a different string here is the App Store
    drift this sprint set out to prevent."""
    from app.services.copy import (
        DEGRADATION_PRIMARY_CONCERN,
        DEGRADATION_RECOMMENDED_ACTIONS,
        DEGRADATION_URGENCY,
    )

    def claude(_n: int) -> Any:
        return UpstreamError("down")

    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(lambda _n: UpstreamError("down")),
        claude=FakeClaude(claude),
    )
    result = await orchestrator.analyze(_request(text="x"))
    assert result.primary_concern == DEGRADATION_PRIMARY_CONCERN
    assert result.urgency_timeframe == DEGRADATION_URGENCY
    assert tuple(result.recommended_actions) == DEGRADATION_RECOMMENDED_ACTIONS


async def test_cross_verify_fails_keeps_emergency_without_disagreement_flag() -> None:
    """If the cross-verify call ITSELF errors, we keep the EMERGENCY
    classification rather than downgrade. Documented as H-7 in the
    Phase 1 audit: failing closed to MONITOR on a transport hiccup
    during the verify call would be unsafe."""
    g_payload = _provider_payload(triage="EMERGENCY", confidence=0.95)
    e_payload = _provider_payload(triage="EMERGENCY", confidence=0.92)

    def claude(n: int) -> Any:
        # First call (initial analysis) succeeds; second (cross-verify) errors.
        if n == 1:
            return e_payload
        return UpstreamError("verify hiccup")

    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(lambda _n: g_payload),
        claude=FakeClaude(claude),
    )
    result = await orchestrator.analyze(_request(text="something off"))
    assert result.tier_used == 3
    assert result.triage_level == "EMERGENCY"
    # The original tier-3 confidence is preserved.
    assert result.confidence == 0.92
    # Disagreement flag stays False — we couldn't disagree, just couldn't verify.
    assert result.cross_verify_disagreement is False


async def test_emergency_override_uses_centralised_copy() -> None:
    """The pre-AI keyword override path must use copy.py constants —
    matching the discipline applied to the graceful path."""
    from app.services.copy import (
        EMERGENCY_RECOMMENDED_ACTIONS,
        EMERGENCY_URGENCY,
    )

    orchestrator = Orchestrator(
        settings=_settings(),
        gemini=FakeGemini(lambda _n: pytest.fail("AI must not be called")),
        claude=FakeClaude(lambda _n: pytest.fail("AI must not be called")),
    )
    result = await orchestrator.analyze(_request(text="my dog is having a seizure"))
    assert result.urgency_timeframe == EMERGENCY_URGENCY
    assert tuple(result.recommended_actions) == EMERGENCY_RECOMMENDED_ACTIONS
    # Headline echoes the matched keyword for operator + user clarity.
    assert "'seizure'" in result.primary_concern
