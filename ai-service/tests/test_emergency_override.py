"""Emergency override unit tests (roadmap-required: all hardcoded keywords)."""
import pytest

from app.models import TriageLevel
from app.safety import (
    EMERGENCY_KEYWORDS,
    SPECIES_EMERGENCY_KEYWORDS,
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


# --- Phase 5.1: species-specific emergency keywords -------------------------
_SPECIES_CASES = [
    (species, kw) for species, kws in SPECIES_EMERGENCY_KEYWORDS.items() for kw in kws
]


@pytest.mark.parametrize("species,keyword", _SPECIES_CASES)
def test_species_keyword_triggers_for_its_species(species, keyword):
    assert check_emergency_override(f"my {species} is {keyword}", species) is not None


def test_species_keyword_is_species_specific():
    # "not eating" is an EMERGENCY for a rabbit (GI stasis) but only a monitor
    # signal for a dog -> the override must fire for the rabbit, NOT the dog.
    assert check_emergency_override("my rabbit is not eating", "rabbit") is not None
    assert check_emergency_override("my dog is not eating", "dog") is None
    # A space normalizes to the guinea_pig key.
    assert check_emergency_override("my guinea pig is not eating", "guinea pig") is not None


def test_global_keyword_fires_regardless_of_species():
    assert check_emergency_override("my rabbit had a seizure", "rabbit") is not None
    assert check_emergency_override("seizure", None) is not None


def test_keyword_lists_stay_in_sync_with_js_mirror():
    # Parity guard: the species KEYS the Python pipeline knows must match the JS
    # mirror used by the Edge paywall bypass (keep both lists aligned by hand).
    assert set(SPECIES_EMERGENCY_KEYWORDS) == {"rabbit", "guinea_pig", "bird", "reptile"}
