"""Semantic-cache embedding tests (Phase 3.2). No API keys needed: the provider
degrades to None, and the /embed endpoint returns a null embedding."""
from fastapi.testclient import TestClient

from app import config
from app.embeddings import (
    GeminiEmbeddingProvider,
    NullEmbeddingProvider,
    build_embedding_input,
)
from app.main import app
from app.models import PetContext

client = TestClient(app)


def test_config_pins_are_set():
    assert config.EMBEDDING_MODEL  # pinned, non-empty (CR #17)
    assert config.EMBEDDING_DIM == 1536  # matches analyses.embedding vector(1536)
    assert config.SEMANTIC_CACHE_THRESHOLD == 0.90
    assert config.VIDEO_MODEL == "gemini-2.0-flash"  # pinned video model (CR #17)


def test_embedding_input_puts_species_first_and_includes_symptoms():
    text = build_embedding_input(
        PetContext(species="dog", breed="Labrador", age_years=3.0),
        "limping on the back leg",
    )
    assert text.startswith("species: dog")
    assert "breed: Labrador" in text
    assert "symptoms: limping on the back leg" in text


def test_embedding_input_omits_absent_fields():
    text = build_embedding_input(PetContext(species="cat"), None)
    assert text == "species: cat"


def test_null_provider_returns_none():
    assert NullEmbeddingProvider().embed("anything") is None


def test_gemini_provider_without_key_returns_none():
    assert GeminiEmbeddingProvider(api_key="").embed("species: dog") is None


def test_gemini_provider_empty_text_returns_none():
    assert GeminiEmbeddingProvider(api_key="key").embed("   ") is None


def test_embed_endpoint_returns_null_embedding_without_a_key():
    # No GOOGLE_AI_API_KEY in tests -> NullEmbeddingProvider -> embedding null.
    resp = client.post("/embed", json={"text_description": "vomiting", "pet": {"species": "dog"}})
    assert resp.status_code == 200
    body = resp.json()
    assert body["embedding"] is None
    assert body["dim"] == 1536
