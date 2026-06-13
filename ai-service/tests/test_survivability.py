"""GAP-A4 survivability: input caps + provider timeouts/no-retry.

The failure mode being closed: one hung provider (Anthropic default 600s timeout)
pins the only machine's threads -> /health (same pool) stops answering -> Fly
restarts the machine, killing in-flight analyses. We bound inputs (422) and give
both providers an 8s hard timeout with no SDK-level retry stacking.
"""
import json

import pytest
from pydantic import ValidationError

from app.models import AnalyzeRequest, PetContext
from app.providers import ClaudeProvider, GeminiProvider

_VALID = {
    "triage_level": "MONITOR",
    "confidence": 0.9,
    "primary_concern": "x",
    "visible_symptoms": [],
    "differential": [],
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


def test_more_than_six_frames_rejected():
    with pytest.raises(ValidationError):
        AnalyzeRequest(
            input_type="video",
            frame_urls=[f"https://r2/{i}" for i in range(7)],
            pet=PetContext(species="dog"),
        )


# ---- provider timeouts / no retry (GAP-A4) ----
def test_claude_client_constructed_with_timeout_and_no_retries(monkeypatch):
    import anthropic

    monkeypatch.setattr(anthropic, "Anthropic", _RecAnthropic)
    ClaudeProvider(api_key="x").analyze("sys", "text only")
    assert CTOR["anthropic"]["timeout"] == 8.0
    assert CTOR["anthropic"]["max_retries"] == 0


def test_gemini_client_constructed_with_http_timeout(monkeypatch):
    from google import genai

    monkeypatch.setattr(genai, "Client", _RecGenai)
    GeminiProvider(api_key="x").analyze("sys", "text only")
    assert "http_options" in CTOR["genai"]
