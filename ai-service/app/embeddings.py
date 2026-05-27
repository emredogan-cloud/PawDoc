"""Embedding generation for the semantic cache (Phase 3.2).

Best-effort by design: any failure (no key, SDK error, wrong dimension) returns
None, so the caller simply skips the cache and runs the normal pipeline. The
cache is an OPTIONAL cost optimization and must NEVER change, delay, or block a
triage result.
"""
from __future__ import annotations

from typing import Protocol

from . import config
from .models import PetContext


def build_embedding_input(pet: PetContext, text_description: str | None) -> str:
    """Canonical text we embed. Species/breed come FIRST so they dominate the
    vector — different species/breeds land far apart in embedding space — then
    age/sex, then the symptom text. This is the single source of truth for what
    a cache key "means"; the same fields gate the SQL lookup (same species)."""
    parts = [f"species: {pet.species}"]
    if pet.breed:
        parts.append(f"breed: {pet.breed}")
    if pet.age_years is not None:
        parts.append(f"age_years: {pet.age_years}")
    if pet.sex:
        parts.append(f"sex: {pet.sex}")
    if text_description and text_description.strip():
        parts.append(f"symptoms: {text_description.strip()}")
    return " | ".join(parts)


class EmbeddingProvider(Protocol):
    def embed(self, text: str) -> list[float] | None: ...


class GeminiEmbeddingProvider:
    """Google embeddings, pinned model (CR #17), requested at EMBEDDING_DIM
    (1536) to match the `analyses.embedding` vector(1536) column."""

    def __init__(
        self,
        api_key: str,
        model: str = config.EMBEDDING_MODEL,
        dim: int = config.EMBEDDING_DIM,
    ) -> None:
        self._api_key = api_key
        self._model = model
        self._dim = dim

    def embed(self, text: str) -> list[float] | None:
        if not self._api_key or not text.strip():
            return None
        try:
            from google import genai  # lazy
            from google.genai import types

            client = genai.Client(api_key=self._api_key)
            resp = client.models.embed_content(
                model=self._model,
                contents=text,
                config=types.EmbedContentConfig(output_dimensionality=self._dim),
            )
            values = list(resp.embeddings[0].values)
            if len(values) != self._dim:
                return None  # dimension mismatch -> skip cache (safe, never wrong)
            return [float(v) for v in values]
        except Exception:  # noqa: BLE001 — the cache must never break the request path
            return None


class NullEmbeddingProvider:
    """No-op provider (no key, or cache disabled). Always returns None."""

    def embed(self, text: str) -> list[float] | None:  # noqa: ARG002
        return None


def make_embedding_provider() -> EmbeddingProvider:
    if config.SEMANTIC_CACHE_ENABLED and config.GOOGLE_AI_API_KEY:
        return GeminiEmbeddingProvider(config.GOOGLE_AI_API_KEY)
    return NullEmbeddingProvider()
