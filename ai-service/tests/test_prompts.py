"""Prompt builder tests — Phase 5.1 species guidance + Phase 6.1 personalization."""
from app.models import AnalyzeRequest, PetContext
from app.prompts import (
    RECENT_ANALYSES_CAP,
    RECENT_EVENTS_CAP,
    build_personalization_block,
    build_user_prompt,
    species_guidance,
)


def test_guidance_present_for_each_exotic():
    for s in ["rabbit", "guinea_pig", "bird", "reptile"]:
        assert species_guidance(s) != "", s


def test_guidance_empty_for_dog_and_cat():
    assert species_guidance("dog") == ""
    assert species_guidance("cat") == ""
    assert species_guidance("other") == ""


def test_guinea_pig_space_normalizes():
    assert species_guidance("guinea pig") == species_guidance("guinea_pig") != ""


def test_personalization_block_injects_rabbit_guidance():
    # The species note used to live in the dynamic user prompt; Phase 6.1 moves
    # it to the cache-able personalization block so it pays tokens only on the
    # first call within the 5-min ephemeral cache window.
    block = build_personalization_block(PetContext(species="rabbit"))
    assert "Species: rabbit" in block
    assert "GI stasis" in block


def test_personalization_block_no_species_note_for_dog():
    block = build_personalization_block(PetContext(species="dog"))
    assert "Species note" not in block


def test_user_prompt_is_dynamic_only():
    """The per-check prompt must NOT carry the static pet profile any more —
    that's what the personalization block is for (cache-friendly)."""
    prompt = build_user_prompt(
        AnalyzeRequest(
            input_type="text",
            text_description="limping a little",
            pet=PetContext(species="dog", breed="Labrador", age_years=5.0),
        )
    )
    assert "limping a little" in prompt
    assert "Input type: text" in prompt
    # Pet attributes belong to the personalization block now; assert they don't
    # leak into the dynamic per-check string.
    assert "Labrador" not in prompt
    assert "Age (years)" not in prompt
    assert "Species:" not in prompt


def test_personalization_block_renders_recent_analyses_and_events():
    pet = PetContext(species="dog", breed="Golden Retriever", age_years=4.0)
    analyses = [
        {"triage_level": "MONITOR", "primary_concern": "intermittent vomiting",
         "created_at": "2026-05-22T10:00:00Z"},
        {"triage_level": "NORMAL", "primary_concern": "mild ear redness",
         "created_at": "2026-05-15T12:00:00Z"},
    ]
    events = [
        {"event_type": "vaccine", "event_date": "2026-05-20", "notes": "DHPP booster"},
    ]
    block = build_personalization_block(pet, analyses, events)
    assert "Recent analyses" in block
    assert "MONITOR: intermittent vomiting" in block
    assert "[2026-05-22]" in block
    assert "Recent health events" in block
    assert "vaccine: DHPP booster" in block
    # The model is reminded to treat history as background, not ground truth.
    assert "background context, NOT as ground truth" in block


def test_personalization_block_caps_long_histories():
    """A power user with 50 events should not blow up the prompt — the cap
    keeps the cost bounded."""
    big_analyses = [
        {"triage_level": "MONITOR", "primary_concern": f"item {i}",
         "created_at": "2026-05-15T12:00:00Z"}
        for i in range(50)
    ]
    big_events = [
        {"event_type": "vet_visit", "event_date": "2026-05-15", "notes": f"visit {i}"}
        for i in range(50)
    ]
    block = build_personalization_block(PetContext(species="dog"), big_analyses, big_events)
    # Only the most recent N of each are kept; the oldest items must not appear.
    assert "item 0" in block          # newest
    assert f"item {RECENT_ANALYSES_CAP - 1}" in block
    assert f"item {RECENT_ANALYSES_CAP}" not in block
    assert f"visit {RECENT_EVENTS_CAP - 1}" in block
    assert f"visit {RECENT_EVENTS_CAP}" not in block


def test_personalization_block_omits_history_sections_when_empty():
    block = build_personalization_block(PetContext(species="cat"))
    assert "Recent analyses" not in block
    assert "Recent health events" not in block
    # But the pet profile is always present:
    assert "Species: cat" in block


def test_personalization_block_tolerates_missing_fields_in_history_rows():
    # An older row may be missing a primary_concern. The builder must not crash;
    # it should fall back to a safe placeholder.
    block = build_personalization_block(
        PetContext(species="dog"),
        recent_analyses=[{"triage_level": "MONITOR", "created_at": "2026-05-22T10:00:00Z"}],
        recent_events=[{"event_type": "weight_check"}],
    )
    assert "no concern recorded" in block
    assert "weight_check" in block
