"""Phase C (RF-8) — content hardening: a real content moderator is mandatory in
production. Without GOOGLE_AI_API_KEY the service must FAIL CLOSED on a prod
runtime rather than silently fall back to AllowAllModerator (accept-everything).
Dev/test still allow the permissive fallback so the suite + local run work."""
import pytest

from app import config
from app.main import build_moderator
from app.moderation import AllowAllModerator, GeminiModerator


def test_production_without_key_fails_closed(monkeypatch):
    monkeypatch.setattr(config, "GOOGLE_AI_API_KEY", "")
    monkeypatch.setattr(config, "IS_PRODUCTION", True)
    with pytest.raises(RuntimeError):
        build_moderator()


def test_dev_without_key_allows_permissive_fallback(monkeypatch):
    monkeypatch.setattr(config, "GOOGLE_AI_API_KEY", "")
    monkeypatch.setattr(config, "IS_PRODUCTION", False)
    assert isinstance(build_moderator(), AllowAllModerator)


def test_with_key_uses_real_gemini_moderator(monkeypatch):
    monkeypatch.setattr(config, "GOOGLE_AI_API_KEY", "AIza-test-key")
    monkeypatch.setattr(config, "IS_PRODUCTION", True)
    assert isinstance(build_moderator(), GeminiModerator)
