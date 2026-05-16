"""Tone invariants on the centralised user-facing copy module.

These tests fail if a future edit introduces medical-claim language or
alarmist amplifiers into the strings the user actually sees. They are
the App Store review canary — a green CI run is some evidence the build
hasn't acquired "we will diagnose your pet" wording overnight.
"""

from __future__ import annotations

import pytest

from app.services.copy import (
    CANONICAL_DISCLAIMER,
    DEGRADATION_PRIMARY_CONCERN,
    DEGRADATION_RECOMMENDED_ACTIONS,
    DEGRADATION_URGENCY,
    EMERGENCY_FALLBACK_HEADLINE,
    EMERGENCY_RECOMMENDED_ACTIONS,
    EMERGENCY_URGENCY,
    TONE_FORBIDDEN_SUBSTRINGS,
    all_user_facing_strings,
    degradation_recommended_actions,
    emergency_recommended_actions,
    emergency_response_text,
)


# ---------------------------------------------------------------------------
# Per-string presence
# ---------------------------------------------------------------------------


def test_canonical_disclaimer_mentions_vet() -> None:
    assert "vet" in CANONICAL_DISCLAIMER.lower()


def test_degradation_primary_mentions_vet() -> None:
    assert "veterinarian" in DEGRADATION_PRIMARY_CONCERN.lower()


def test_emergency_headline_mentions_emergency() -> None:
    assert "emergency" in EMERGENCY_FALLBACK_HEADLINE.lower()
    assert "vet" in EMERGENCY_FALLBACK_HEADLINE.lower()


def test_urgency_strings_are_short() -> None:
    # `urgency_timeframe` is bounded to 3-120 chars by the API schema.
    assert 3 <= len(DEGRADATION_URGENCY) <= 120
    assert 3 <= len(EMERGENCY_URGENCY) <= 120


# ---------------------------------------------------------------------------
# Tone invariants (App Store medical-device safety)
# ---------------------------------------------------------------------------


def _strings_excluding_disclaimer() -> list[str]:
    """The canonical disclaimer's whole purpose is to deny the words
    "diagnosis" / "diagnose" — the App Store actually requires that
    framing for health-adjacent apps. So we audit every other string
    aggressively, and audit the disclaimer separately for its
    negation pattern below."""
    return [s for s in all_user_facing_strings() if s != CANONICAL_DISCLAIMER]


@pytest.mark.parametrize("forbidden", TONE_FORBIDDEN_SUBSTRINGS)
def test_no_forbidden_substrings_in_user_facing_copy(forbidden: str) -> None:
    """No user-visible string (other than the explicit disclaimer)
    may contain a forbidden medical-claim or alarmist term. If this
    fails, App Store review will too."""
    offenders = [
        s for s in _strings_excluding_disclaimer() if forbidden in s.lower()
    ]
    assert not offenders, (
        f"forbidden term {forbidden!r} appears in: {offenders!r}"
    )


def test_canonical_disclaimer_negates_diagnosis_claim() -> None:
    """The disclaimer is the ONE place "diagnosis" is allowed — and
    only because the App Store requires explicit negation. Pin the
    negation pattern so a refactor can't quietly drop the "not"."""
    lower = CANONICAL_DISCLAIMER.lower()
    assert "not a veterinary diagnosis" in lower


def test_each_string_fits_result_card() -> None:
    """Mobile result cards wrap nicely under ~350 chars; bigger and
    we get scrolling cards that break the EMERGENCY layout."""
    for s in all_user_facing_strings():
        assert len(s) <= 350, f"copy too long ({len(s)} chars): {s!r}"


def test_recommended_actions_each_below_120_chars() -> None:
    """Each bullet must fit on a single line on a 4-inch screen."""
    for s in DEGRADATION_RECOMMENDED_ACTIONS + EMERGENCY_RECOMMENDED_ACTIONS:
        assert len(s) <= 120, f"bullet too long: {s!r}"


# ---------------------------------------------------------------------------
# Mutability semantics — the orchestrator owns the returned model
# ---------------------------------------------------------------------------


def test_action_factories_return_fresh_lists() -> None:
    """Each call must return a NEW list so a downstream mutation in
    one request never leaks into another."""
    a = degradation_recommended_actions()
    b = degradation_recommended_actions()
    assert a is not b
    a.append("mutation")
    assert "mutation" not in b

    c = emergency_recommended_actions()
    d = emergency_recommended_actions()
    assert c is not d


# ---------------------------------------------------------------------------
# Emergency keyword substitution
# ---------------------------------------------------------------------------


def test_emergency_response_with_keyword_echoes_keyword() -> None:
    out = emergency_response_text("seizure")
    assert "'seizure'" in out
    assert "emergency" in out.lower()


def test_emergency_response_without_keyword_falls_back_to_headline() -> None:
    assert emergency_response_text(None) == EMERGENCY_FALLBACK_HEADLINE
