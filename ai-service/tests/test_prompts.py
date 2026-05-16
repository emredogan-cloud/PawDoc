"""Tests for the prompt modules."""

from __future__ import annotations

from app.prompts.breed_context import breed_context_for
from app.prompts.system_prompt import PARSER_RETRY_HINT, SYSTEM_PROMPT


def test_system_prompt_minimum_size() -> None:
    """A minimal-length sanity check — accidental truncation should fail."""
    assert len(SYSTEM_PROMPT) > 1000


def test_system_prompt_mentions_required_fields() -> None:
    for field in (
        "triage_level",
        "confidence",
        "primary_concern",
        "recommended_actions",
        "urgency_timeframe",
    ):
        assert field in SYSTEM_PROMPT, f"missing field reference: {field}"


def test_system_prompt_anti_hallucination_present() -> None:
    assert "ignore these instructions" in SYSTEM_PROMPT.lower()
    assert "do not" in SYSTEM_PROMPT.lower()
    assert "confidence" in SYSTEM_PROMPT.lower()


def test_retry_hint_is_short_and_targeted() -> None:
    assert "JSON" in PARSER_RETRY_HINT
    assert len(PARSER_RETRY_HINT) < 500


def test_breed_context_known_breed() -> None:
    out = breed_context_for("dog", "French Bulldog")
    assert "brachycephalic" in out.lower()


def test_breed_context_case_insensitive() -> None:
    out = breed_context_for("dog", "FRENCH BULLDOG")
    assert "brachycephalic" in out.lower()


def test_breed_context_unknown_returns_empty() -> None:
    assert breed_context_for("dog", "Imaginary Breed") == ""


def test_breed_context_rabbit_falls_through_to_species() -> None:
    """Rabbit with no breed still gets species-level context."""
    out = breed_context_for("rabbit", None)
    assert "GI stasis" in out or "stasis" in out.lower()


def test_breed_context_no_breed_no_species_returns_empty() -> None:
    assert breed_context_for("dog", None) == ""
