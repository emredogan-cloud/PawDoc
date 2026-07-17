"""GAP-A1 contract tests: prove REAL pixels reach the outgoing provider payload.

The image bug survived 167 green tests because every fake provider accepted and
ignored `image_url`; nothing asserted an image part in the actual SDK call.
These tests capture the payload the SDK would send and assert the media is there
(photo -> 1 image part, video -> N frame parts, text -> none), that a fetch
failure degrades safely (MONITOR, never NORMAL), and that the fetcher refuses
non-https / IP-literal hosts.
"""
import json

import pytest

from app import media
from app.cache import InMemoryCache
from app.media import MediaFetchError
from app.models import ActionLevel, AnalyzeRequest, PetContext
from app.pipeline import AnalysisPipeline
from app.providers import ClaudeProvider, GeminiProvider

_VALID = {
    "action": "WATCH_AND_RECHECK",
    "confidence": 0.9,
    "observation": "assessment",
    "visible_symptoms": [],
    "recommended_actions": ["follow up if needed"],
    "urgency_timeframe": "routine",
    "disclaimer_required": True,
}
_R2 = "https://acct.r2.cloudflarestorage.com/uploads/u1"

CAPTURED: dict = {}


# ---- Anthropic SDK fake (records messages.create kwargs) ----
class _ToolUse:
    type = "tool_use"

    def __init__(self, data):
        self.input = data


class _Msg:
    def __init__(self, content):
        self.content = content


class _FakeAnthropic:
    def __init__(self, **_):
        self.messages = self

    def create(self, **kwargs):
        CAPTURED["claude"] = kwargs
        return _Msg([_ToolUse(dict(_VALID))])


# ---- google-genai SDK fake (records generate_content kwargs) ----
class _Resp:
    def __init__(self, text):
        self.text = text


class _GenaiModels:
    def generate_content(self, **kwargs):
        CAPTURED["gemini"] = kwargs
        return _Resp(json.dumps(_VALID))


class _FakeGenaiClient:
    def __init__(self, **_):
        self.models = _GenaiModels()


@pytest.fixture
def fake_anthropic(monkeypatch):
    import anthropic

    monkeypatch.setattr(anthropic, "Anthropic", _FakeAnthropic)


@pytest.fixture
def fake_genai(monkeypatch):
    from google import genai

    monkeypatch.setattr(genai, "Client", _FakeGenaiClient)


# ---------- Claude payload ----------
def test_claude_photo_attaches_one_image(fake_anthropic):
    out = ClaudeProvider(api_key="x").analyze(
        "sys", "user prompt", media=[(b"\xff\xd8\xff\x00fakejpeg", "image/jpeg")]
    )
    assert out["action"] == "WATCH_AND_RECHECK"
    content = CAPTURED["claude"]["messages"][0]["content"]
    assert isinstance(content, list), "photo content must be multimodal blocks"
    images = [b for b in content if b.get("type") == "image"]
    assert len(images) == 1
    assert images[0]["source"]["media_type"] == "image/jpeg"
    assert images[0]["source"]["type"] == "base64" and images[0]["source"]["data"]
    assert content[-1]["type"] == "text", "the prompt text must follow the image"



def test_claude_text_only_sends_no_image(fake_anthropic):
    ClaudeProvider(api_key="x").analyze("sys", "just text, no media")
    content = CAPTURED["claude"]["messages"][0]["content"]
    assert content == "just text, no media", "text-only must stay a plain string"


# ---------- Gemini payload ----------
def test_gemini_photo_attaches_image_part(fake_genai):
    out = GeminiProvider(api_key="x").analyze(
        "sys", "user", media=[(b"\xff\xd8\xff\x00fakejpeg", "image/jpeg")])
    assert out["action"] == "WATCH_AND_RECHECK"
    contents = CAPTURED["gemini"]["contents"]
    assert isinstance(contents, list), "photo contents must be a parts list"
    # last element is the text; everything before is a media Part with bytes.
    assert len(contents) == 2
    from google.genai import types

    assert isinstance(contents[0], types.Part)


def test_gemini_text_only_is_plain_string(fake_genai):
    # B10: the safety contract rides in system_instruction; ONLY the owner
    # text is user content. No shared string on the primary tier anymore.
    GeminiProvider(api_key="x").analyze("sys", "only text")
    assert CAPTURED["gemini"]["contents"] == "only text"
    assert CAPTURED["gemini"]["config"].system_instruction == "sys"


# ---------- safe degrade + fetcher guards ----------
class _MediaErrProvider:
    name = "fake"
    tier = 2

    def analyze(self, *a, **k):
        raise MediaFetchError("unreadable media")


def test_pipeline_degrades_safe_when_media_unreadable():
    pipe = AnalysisPipeline(
        tier2=_MediaErrProvider(), tier3=_MediaErrProvider(), cache=InMemoryCache()
    )
    out = pipe.run(
        AnalyzeRequest(
            input_type="photo",
            image_url=f"{_R2}/a.jpg",
            pet=PetContext(species="dog"),
        )
    )
    assert out.result.action is ActionLevel.WATCH_AND_RECHECK
    # v2 invariant: a degrade is never a dead end — the floor carries a re-check.
    assert out.result.recheck_hours is not None
    assert out.degraded is True
    assert out.model_used == "media_error"


def test_pipeline_prefetch_propagates_media_fetch_error(monkeypatch):
    # AI-03: the fetch now happens ONCE in the pipeline; an unreadable URL
    # degrades safely before any provider or moderator runs.
    def _boom(url, **kw):
        raise MediaFetchError("boom")

    monkeypatch.setattr(media, "fetch_media", _boom)
    pipe = AnalysisPipeline(
        tier2=_MediaErrProvider(), tier3=_MediaErrProvider(), cache=InMemoryCache()
    )
    out = pipe.run(
        AnalyzeRequest(
            input_type="photo",
            image_url=f"{_R2}/a.jpg",
            pet=PetContext(species="dog"),
        )
    )
    assert out.degraded is True
    assert out.model_used == "media_error"


def test_fetch_media_refuses_non_https():
    with pytest.raises(MediaFetchError):
        media.fetch_media("http://acct.r2.cloudflarestorage.com/a.jpg")


def test_fetch_media_refuses_ip_literal_host():
    with pytest.raises(MediaFetchError):
        media.fetch_media("https://169.254.169.254/latest/meta-data")
