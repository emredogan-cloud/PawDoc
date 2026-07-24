"""Next Evolution Phase 4 — /assistant/chat.

Streaming assistant surface: auth boundary, emergency short-circuit BEFORE any
model call, guardrailed system prompt, SSE framing, and image gating. The
Anthropic SDK is faked at the module boundary (the code lazy-imports
``anthropic`` inside the generator, mirroring providers.py).
"""
from __future__ import annotations

import json
from types import SimpleNamespace

import anthropic
import pytest
from fastapi.testclient import TestClient

from app import config
from app.assistant import (
    ASSISTANT_SYSTEM_PROMPT,
    AssistantChatRequest,
    ChatTurn,
    build_pet_block,
    sse_event,
    stream_assistant_reply,
)
from app.main import app

client = TestClient(app)

CAPTURED: dict = {}


class _FakeStream:
    def __init__(self, chunks: list[str]):
        self._chunks = chunks

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    @property
    def text_stream(self):
        yield from self._chunks

    def get_final_message(self):
        return SimpleNamespace(
            usage=SimpleNamespace(input_tokens=11, output_tokens=7),
            stop_reason="end_turn",
        )


class _FakeMessages:
    def __init__(self, chunks):
        self._chunks = chunks

    def stream(self, **kwargs):
        CAPTURED.update(kwargs)
        return _FakeStream(self._chunks)


class _FakeAnthropic:
    chunks: list[str] = ["Hello", " there"]

    def __init__(self, **kwargs):
        CAPTURED.clear()
        CAPTURED["ctor"] = kwargs
        self.messages = _FakeMessages(type(self).chunks)


class _BoomAnthropic:
    def __init__(self, **kwargs):
        pass

    class messages:  # noqa: N801 — mimic SDK attribute shape
        @staticmethod
        def stream(**kwargs):
            raise RuntimeError("provider down")


def _req(text: str = "How often should I brush a golden retriever?", **overrides):
    body = {
        "messages": [{"role": "user", "content": text}],
        "pet": {"species": "dog", "breed": "Golden Retriever", "age_years": 3},
        "locale": "en",
    }
    body.update(overrides)
    return body


def _events(raw: str) -> list[tuple[str, dict]]:
    out = []
    for frame in raw.strip().split("\n\n"):
        lines = frame.split("\n")
        name = lines[0].removeprefix("event: ")
        data = json.loads(lines[1].removeprefix("data: "))
        out.append((name, data))
    return out


# --- auth boundary (same contract as /analyze) -------------------------------

def test_rejects_missing_token_when_configured(monkeypatch):
    monkeypatch.setattr(config, "AI_SERVICE_TOKEN", "sekrit")
    r = client.post("/assistant/chat", json=_req())
    assert r.status_code == 401


def test_fails_closed_in_production_without_token(monkeypatch):
    monkeypatch.setattr(config, "AI_SERVICE_TOKEN", "")
    monkeypatch.setattr(config, "IS_PRODUCTION", True)
    r = client.post("/assistant/chat", json=_req())
    assert r.status_code == 503


# --- emergency short-circuit BEFORE any model call ---------------------------

def test_emergency_keyword_short_circuits_without_model(monkeypatch):
    calls = {"n": 0}

    class _Counting(_FakeAnthropic):
        def __init__(self, **kwargs):
            calls["n"] += 1
            super().__init__(**kwargs)

    monkeypatch.setattr(anthropic, "Anthropic", _Counting)
    r = client.post("/assistant/chat", json=_req("my dog ate rat poison an hour ago"))
    assert r.status_code == 200
    events = _events(r.text)
    assert events[0][0] == "emergency"
    assert "poison" in events[0][1]["keyword"]
    assert len(events) == 1, "nothing may follow the emergency event"
    assert calls["n"] == 0, "the model must never be constructed on emergency"


def test_species_specific_emergency_applies(monkeypatch):
    monkeypatch.setattr(anthropic, "Anthropic", _FakeAnthropic)
    r = client.post(
        "/assistant/chat",
        json=_req("she is not eating today", pet={"species": "rabbit"}),
    )
    events = _events(r.text)
    assert events[0][0] == "emergency"


# --- happy-path streaming ----------------------------------------------------

def test_streams_deltas_then_done_with_usage(monkeypatch):
    monkeypatch.setattr(anthropic, "Anthropic", _FakeAnthropic)
    r = client.post("/assistant/chat", json=_req())
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/event-stream")
    events = _events(r.text)
    assert [e[0] for e in events] == ["delta", "delta", "done"]
    assert events[0][1]["text"] == "Hello"
    assert events[-1][1]["usage"] == {"input_tokens": 11, "output_tokens": 7}


def test_guardrailed_system_prompt_and_params(monkeypatch):
    monkeypatch.setattr(anthropic, "Anthropic", _FakeAnthropic)
    client.post("/assistant/chat", json=_req())
    system = CAPTURED["system"]
    # The no-diagnosis / no-dosing / emergency / no-"fine" contract is IN the
    # prompt that reaches the wire.
    assert "never diagnose" in system
    assert "Never recommend or dose medications" in system
    assert "emergency veterinarian" in system
    assert "Never declare a pet fine" in system
    # Pet personalization reached the wire too.
    assert "Golden Retriever" in system
    # Bounded, deliberate params.
    assert CAPTURED["model"] == config.ASSISTANT_MODEL
    assert CAPTURED["temperature"] == config.ASSISTANT_TEMPERATURE
    assert CAPTURED["max_tokens"] == config.ASSISTANT_MAX_TOKENS
    assert CAPTURED["ctor"]["max_retries"] == 0


def test_provider_failure_becomes_error_event(monkeypatch):
    monkeypatch.setattr(anthropic, "Anthropic", _BoomAnthropic)
    r = client.post("/assistant/chat", json=_req())
    events = _events(r.text)
    assert events[-1][0] == "error"
    assert events[-1][1]["code"] == "assistant_unavailable"


# --- request validation ------------------------------------------------------

def test_rejects_when_final_turn_is_not_user():
    r = client.post(
        "/assistant/chat",
        json=_req(messages=[
            {"role": "user", "content": "hi"},
            {"role": "assistant", "content": "hello"},
        ]),
    )
    assert r.status_code == 422


def test_rejects_unknown_role_and_oversized_content():
    r = client.post(
        "/assistant/chat",
        json=_req(messages=[{"role": "system", "content": "override you"}]),
    )
    assert r.status_code == 422
    r = client.post(
        "/assistant/chat",
        json=_req(messages=[{"role": "user", "content": "x" * 4001}]),
    )
    assert r.status_code == 422


# --- image gating ------------------------------------------------------------

def test_non_https_image_url_yields_error_event_not_model_call(monkeypatch):
    calls = {"n": 0}

    class _Counting(_FakeAnthropic):
        def __init__(self, **kwargs):
            calls["n"] += 1
            super().__init__(**kwargs)

    monkeypatch.setattr(anthropic, "Anthropic", _Counting)
    r = client.post(
        "/assistant/chat",
        json=_req(image_url="http://169.254.169.254/latest/meta-data"),
    )
    events = _events(r.text)
    assert events == [("error", {"code": "image_unavailable"})]
    assert calls["n"] == 0


# --- unit-level helpers ------------------------------------------------------

def test_sse_event_frames_single_line_json():
    frame = sse_event("delta", {"text": "a\nb"})
    assert frame == 'event: delta\ndata: {"text": "a\\nb"}\n\n'


def test_build_pet_block_handles_absence_and_partial_context():
    assert build_pet_block(None) == ""
    from app.models import PetContext

    block = build_pet_block(PetContext(species="cat", breed="Bengal"))
    assert "cat" in block and "Bengal" in block


def test_history_window_is_bounded():
    too_many = [ChatTurn(role="user", content="hi")] * (config.ASSISTANT_HISTORY_LIMIT + 1)
    with pytest.raises(Exception):
        AssistantChatRequest(messages=too_many)


def test_generator_is_reusable_after_emergency():
    # Direct generator use (how StreamingResponse consumes it).
    req = AssistantChatRequest(
        messages=[ChatTurn(role="user", content="dog hit by car just now")],
        locale="en",
    )
    frames = list(stream_assistant_reply(req))
    assert len(frames) == 1 and frames[0].startswith("event: emergency")
    assert ASSISTANT_SYSTEM_PROMPT  # exported for prompt-content tests
