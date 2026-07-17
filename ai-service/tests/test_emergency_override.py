"""Emergency override unit tests (roadmap-required: all hardcoded keywords)."""
import pytest

from app.models import ActionLevel
from app.safety import (
    EMERGENCY_KEYWORDS,
    EMERGENCY_KEYWORDS_BY_LOCALE,
    SPECIES_EMERGENCY_KEYWORDS,
    SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE,
    SUPPORTED_LOCALES,
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
    assert result.action is ActionLevel.GET_HELP_NOW
    assert result.confidence == 1.0
    assert result.disclaimer_required is True
    assert "seizure" in result.observation


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


# --- Phase 5.4 / CR #11: localized emergency keywords ---------------------
def test_supported_locales_includes_en_and_de():
    assert set(SUPPORTED_LOCALES) == {"en", "de"}


def test_de_global_keyword_fires_under_locale_de():
    # German "Krampfanfall" must trip the override when locale=de.
    assert check_emergency_override(
        "Der Hund hatte einen Krampfanfall.", "dog", "de"
    ) is not None
    assert check_emergency_override(
        "Verdacht auf Vergiftung mit Schokolade.", "dog", "de"
    ) is not None


def test_de_species_keyword_is_species_specific():
    # "frisst nicht" -> emergency for rabbit (GI stasis), not for dog.
    assert check_emergency_override("Mein Kaninchen frisst nicht.", "rabbit", "de") is not None
    assert check_emergency_override("Mein Hund frisst nicht.", "dog", "de") is None


def test_locales_do_not_cross_match():
    # German phrase must not fire under English keywords.
    assert check_emergency_override(
        "Der Hund hatte einen Krampfanfall.", "dog", "en"
    ) is None
    # English phrase must not fire under German keywords.
    assert check_emergency_override("my dog had a seizure", "dog", "de") is None


def test_unknown_locale_falls_back_to_english_safe_default():
    # Unknown locale -> 'en' coverage, never an empty keyword set.
    assert check_emergency_override("my dog had a seizure", "dog", "fr") is not None
    assert check_emergency_override("my dog had a seizure", "dog", None) is not None


def test_bcp47_de_de_normalizes_to_de():
    assert check_emergency_override(
        "Der Hund hatte einen Krampfanfall.", "dog", "de-DE"
    ) is not None


def test_de_species_keys_match_en_species_keys():
    # Defense-in-depth: a species supported in EN must have a DE counterpart.
    assert set(SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE["de"]) == set(
        SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE["en"]
    )


def test_back_compat_aliases_point_to_english_lists():
    assert EMERGENCY_KEYWORDS is EMERGENCY_KEYWORDS_BY_LOCALE["en"]
    assert SPECIES_EMERGENCY_KEYWORDS is SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE["en"]
