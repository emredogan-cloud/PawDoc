"""Species-specific prompt guidance tests (Phase 5.1)."""
from app.models import AnalyzeRequest, PetContext
from app.prompts import build_user_prompt, species_guidance


def test_guidance_present_for_each_exotic():
    for s in ["rabbit", "guinea_pig", "bird", "reptile"]:
        assert species_guidance(s) != "", s


def test_guidance_empty_for_dog_and_cat():
    assert species_guidance("dog") == ""
    assert species_guidance("cat") == ""
    assert species_guidance("other") == ""


def test_guinea_pig_space_normalizes():
    assert species_guidance("guinea pig") == species_guidance("guinea_pig") != ""


def test_build_user_prompt_injects_rabbit_guidance():
    prompt = build_user_prompt(
        AnalyzeRequest(
            input_type="text",
            text_description="not eating since yesterday",
            pet=PetContext(species="rabbit"),
        )
    )
    assert "Species: rabbit" in prompt
    assert "GI stasis" in prompt  # the rabbit red-flag context is present


def test_build_user_prompt_has_no_species_note_for_dog():
    prompt = build_user_prompt(
        AnalyzeRequest(
            input_type="text",
            text_description="limping a little",
            pet=PetContext(species="dog"),
        )
    )
    assert "Species note" not in prompt
