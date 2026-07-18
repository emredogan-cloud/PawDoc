"""GAP-A4 survivability: input caps + provider timeouts/no-retry.

The failure mode being closed: one hung provider (Anthropic default 600s timeout)
pins the only machine's threads -> /health (same pool) stops answering -> Fly
restarts the machine, killing in-flight analyses. We bound inputs (422) and give
both providers a hard timeout with no SDK-level retry stacking — Gemini 12s (the
API's 10s floor + headroom), Claude 15s (enough for a Sonnet tool_use response),
both well under the Edge's 25s budget.
"""
import json

import pytest
from pydantic import ValidationError

from app.models import AnalyzeRequest, PetContext
from app.providers import ClaudeProvider, GeminiProvider

_VALID = {
    "action": "WATCH_AND_RECHECK",
    "confidence": 0.9,
    "observation": "x",
    "visible_symptoms": [],
    "recommended_actions": ["a"],
    "urgency_timeframe": "soon",
    "disclaimer_required": True,
}
CTOR: dict = {}


class _RecAnthropic:
    def __init__(self, **kwargs):
        CTOR["anthropic"] = kwargs
        self.messages = self

    def create(self, **_):
        tu = type("TU", (), {"type": "tool_use", "input": dict(_VALID)})()
        return type("Msg", (), {"content": [tu]})()


class _RecModels:
    def generate_content(self, **_):
        return type("Resp", (), {"text": json.dumps(_VALID)})()


class _RecGenai:
    def __init__(self, **kwargs):
        CTOR["genai"] = kwargs
        self.models = _RecModels()


# ---- input caps (GAP-A4) ----
def test_text_over_4000_chars_rejected():
    with pytest.raises(ValidationError):
        AnalyzeRequest(
            input_type="text", text_description="x" * 4001, pet=PetContext(species="dog")
        )


def test_text_at_cap_is_accepted():
    r = AnalyzeRequest(
        input_type="text", text_description="x" * 4000, pet=PetContext(species="dog")
    )
    assert r.text_description is not None



# ---- provider timeouts / no retry (GAP-A4) ----
def test_claude_client_constructed_with_timeout_and_no_retries(monkeypatch):
    import anthropic

    monkeypatch.setattr(anthropic, "Anthropic", _RecAnthropic)
    ClaudeProvider(api_key="x").analyze("sys", "text only")
    # 15s (was 8s, which timed out every Sonnet tool_use call). Bounded, no retry.
    assert CTOR["anthropic"]["timeout"] == 15.0
    assert CTOR["anthropic"]["max_retries"] == 0


def test_gemini_http_timeout_meets_api_minimum(monkeypatch):
    from google import genai

    monkeypatch.setattr(genai, "Client", _RecGenai)
    GeminiProvider(api_key="x").analyze("sys", "text only")
    # The Gemini API REJECTS deadlines < 10s (400 INVALID_ARGUMENT); 8s failed
    # every call. Guard the floor so the regression can't return.
    assert "http_options" in CTOR["genai"]
    assert CTOR["genai"]["http_options"].timeout >= 10000
