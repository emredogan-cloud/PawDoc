"""Emergency override unit tests (roadmap-required: all hardcoded keywords)."""
import pytest

from app.models import TriageLevel
from app.safety import (
    EMERGENCY_KEYWORDS,
    check_emergency_override,
    emergency_override_result,
)


@pytest.mark.parametrize("keyword", EMERGENCY_KEYWORDS)
def test_every_keyword_triggers_override(keyword):
    # Embedded in a realistic sentence; match is case-insensitive.
    text = f"My dog is {keyword.upper()} and I am worried."
    assert check_emergency_override(text) is not None


def test_keyword_count_matches_source_list():
    # Source roadmap lists 23 (the decomposed roadmap's "14" undercounts).
    assert len(EMERGENCY_KEYWORDS) == 23
    assert len(set(EMERGENCY_KEYWORDS)) == 23  # no duplicates


def test_non_emergency_text_does_not_trigger():
    assert check_emergency_override("happy healthy puppy, eating well") is None
    assert check_emergency_override("") is None
    assert check_emergency_override(None) is None


def test_override_result_is_emergency_with_disclaimer():
    result = emergency_override_result("seizure")
    assert result.triage_level is TriageLevel.EMERGENCY
    assert result.confidence == 1.0
    assert result.disclaimer_required is True
    assert "seizure" in result.primary_concern
