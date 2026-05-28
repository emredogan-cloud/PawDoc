"""AI Health Journal tests (Phase 5.3). No real OpenAI calls — a fake provider
is injected via FastAPI's dependency override."""
from fastapi.testclient import TestClient

from app import config
from app.journal import (
    JOURNAL_SYSTEM_PROMPT,
    NullJournalProvider,
    OpenAIJournalProvider,
    build_journal_prompt,
)
from app.main import app, get_journal_provider
from app.models import JournalRequest, PetContext

client = TestClient(app)


def _req(**overrides) -> JournalRequest:
    base = {
        "pet": PetContext(species="dog", breed="Labrador", age_years=3.0),
        "week_start_date": "2026-05-25",
        "analyses": [{"created_at": "2026-05-26", "triage_level": "MONITOR", "primary_concern": "Mild limp"}],
        "events": [{"event_date": "2026-05-27", "event_type": "weight", "notes": "+0.3kg"}],
    }
    base.update(overrides)
    return JournalRequest(**base)


def test_system_prompt_carries_anti_hallucination_guards():
    assert "DO NOT diagnose" in JOURNAL_SYSTEM_PROMPT
    assert "DO NOT override" in JOURNAL_SYSTEM_PROMPT
    assert "ONLY what is in the provided history" in JOURNAL_SYSTEM_PROMPT
    assert "not a veterinary diagnosis" in JOURNAL_SYSTEM_PROMPT


def test_build_journal_prompt_lists_pet_history():
    prompt = build_journal_prompt(_req())
    assert "Pet: dog (Labrador)" in prompt
    assert "Week starting: 2026-05-25" in prompt
    assert "MONITOR" in prompt
    assert "Mild limp" in prompt
    assert "weight" in prompt


def test_build_journal_prompt_handles_empty_history():
    prompt = build_journal_prompt(_req(analyses=[], events=[]))
    assert "none logged this week" in prompt
    assert "Logged events: none" in prompt


def test_config_pins_for_openai():
    assert config.OPENAI_MODEL  # pinned (CR #17)
    assert config.JOURNAL_TEMPERATURE == 0.4
    assert config.JOURNAL_MAX_TOKENS == 500


def test_null_provider_returns_none():
    assert NullJournalProvider().generate(_req()) is None


def test_openai_provider_without_key_is_none():
    assert OpenAIJournalProvider(api_key="").generate(_req()) is None


def test_endpoint_returns_null_narrative_without_a_key():
    # Default get_journal_provider with no OPENAI_API_KEY -> NullJournalProvider.
    resp = client.post("/generate_journal", json={
        "pet": {"species": "dog"},
        "week_start_date": "2026-05-25",
        "analyses": [],
        "events": [],
    })
    assert resp.status_code == 200
    assert resp.json()["narrative"] is None
    assert resp.json()["model"] is None


def test_endpoint_returns_narrative_with_a_fake_provider():
    # Inject a deterministic fake provider via FastAPI's dependency override.
    class Fake:
        def generate(self, request):
            assert request.pet.species == "rabbit"
            return "A calm, quiet week for Lily — keep an eye on her appetite."
    app.dependency_overrides[get_journal_provider] = lambda: Fake()
    try:
        resp = client.post("/generate_journal", json={
            "pet": {"species": "rabbit"},
            "week_start_date": "2026-05-25",
            "analyses": [],
            "events": [],
        })
        assert resp.status_code == 200
        body = resp.json()
        assert "calm" in body["narrative"]
        assert body["model"] == config.OPENAI_MODEL
    finally:
        app.dependency_overrides.pop(get_journal_provider, None)
