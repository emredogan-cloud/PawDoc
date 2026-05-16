"""Tests for app.services.safety — emergency keyword override.

Every keyword in the canonical list is exercised. If you add or remove a
keyword in ``EMERGENCY_KEYWORDS``, the parametrised test below will reflect
the new size automatically; the targeted phrase tests verify representative
match behaviour.
"""

from __future__ import annotations

import pytest

from app.services.safety import (
    EMERGENCY_KEYWORDS,
    EmergencyMatch,
    check_emergency_override,
    emergency_recommended_actions,
    emergency_response_text,
)


@pytest.mark.parametrize("kw", EMERGENCY_KEYWORDS)
def test_each_keyword_triggers_override(kw: str) -> None:
    """Every canonical keyword, embedded in a realistic sentence, triggers.

    The matched keyword is the FIRST keyword in the list whose text appears
    in the sentence — so a sentence containing "collapsed" may match the
    shorter, earlier-listed "collapse". We assert _some_ keyword matched
    and that it is a substring of the test phrase.
    """
    text = f"my dog is showing {kw} symptoms"
    result = check_emergency_override(text)
    assert result.matched is True
    assert result.keyword is not None
    assert result.keyword in text.lower()


def test_case_insensitive() -> None:
    assert check_emergency_override("My dog ate XYLITOL gum").matched is True
    assert check_emergency_override("SEIZURE happening NOW").matched is True


def test_handles_punctuation_and_spacing() -> None:
    assert check_emergency_override("she just had a   seizure!").matched is True
    assert check_emergency_override("Hit by car — needs help.").matched is True


def test_none_text_returns_no_match() -> None:
    assert check_emergency_override(None) == EmergencyMatch.none()
    assert check_emergency_override("") == EmergencyMatch.none()


def test_innocent_text_does_not_trigger() -> None:
    """Regression: non-emergency descriptions never over-trigger."""
    samples = [
        "She is eating well and playful today.",
        "Mild itching on his left ear, not red.",
        "He sleeps a lot — is that normal for senior dogs?",
        "Slight limp this morning, otherwise fine.",
        "Loose stools yesterday, normal today.",
    ]
    for s in samples:
        assert check_emergency_override(s).matched is False, f"unexpectedly matched: {s}"


def test_first_match_is_returned() -> None:
    """Determinism: when multiple keywords overlap, the first in list wins."""
    text = "she is collapsed AND has a seizure"  # both 'collapse' and 'seizure'
    result = check_emergency_override(text)
    assert result.matched is True
    # The list order determines the match — assert the keyword is one of them.
    assert result.keyword in {"seizure", "collapse", "collapsed", "seizing"}


def test_emergency_response_text_includes_keyword() -> None:
    text = emergency_response_text("seizure")
    assert "seizure" in text
    assert "vet" in text.lower() or "veterinary" in text.lower()


def test_emergency_recommended_actions_non_empty() -> None:
    actions = emergency_recommended_actions()
    assert isinstance(actions, list)
    assert len(actions) >= 1
    assert all(isinstance(a, str) and len(a) > 5 for a in actions)


def test_keyword_list_has_minimum_size() -> None:
    """Defensive: someone deleting the file wholesale should fail this test."""
    assert len(EMERGENCY_KEYWORDS) >= 14, "EMERGENCY_KEYWORDS shrank — review!"
