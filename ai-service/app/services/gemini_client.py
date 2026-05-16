"""Gemini 2.0 Flash client — Tier 2 of the AI pipeline.

We use the Google AI Studio HTTPS endpoint directly via httpx rather than
adding the ``google-genai`` SDK because:

1. The endpoint is stable and small; the SDK adds dependencies + a layer to
   mock through.
2. We rely on the ``responseMimeType: application/json`` + ``responseSchema``
   features which are first-class in the v1beta REST API.
3. ``httpx.MockTransport`` lets tests stub responses cleanly without monkey-
   patching the SDK internals.

The client is a class so tests can inject an alternative ``httpx.AsyncClient``
(for ``MockTransport``) without touching env vars.
"""

from __future__ import annotations

from typing import Any

import httpx

from app.core.config import Settings
from app.core.exceptions import UpstreamError
from app.core.logging import get_logger
from app.models.schemas import AnalysisRequest

log = get_logger(__name__)

_GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models"

# JSON schema mirrored from AnalysisProviderOutput. Embedded literal — both
# providers receive the same shape; keeping it inline makes drift between
# providers immediately reviewable in code review.
_RESPONSE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "triage_level": {"type": "string", "enum": ["EMERGENCY", "MONITOR", "NORMAL"]},
        "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0},
        "primary_concern": {"type": "string", "minLength": 10, "maxLength": 500},
        "visible_symptoms": {"type": "array", "items": {"type": "string"}, "maxItems": 20},
        "differential": {"type": "array", "items": {"type": "string"}, "maxItems": 10},
        "recommended_actions": {
            "type": "array",
            "items": {"type": "string"},
            "minItems": 1,
            "maxItems": 10,
        },
        "urgency_timeframe": {"type": "string", "minLength": 3, "maxLength": 120},
    },
    "required": [
        "triage_level",
        "confidence",
        "primary_concern",
        "recommended_actions",
        "urgency_timeframe",
    ],
}


class GeminiClient:
    """Async client for Gemini's generateContent endpoint."""

    def __init__(self, settings: Settings, *, client: httpx.AsyncClient | None = None) -> None:
        self._settings = settings
        self._client = client or httpx.AsyncClient(timeout=settings.gemini_timeout_s)

    async def aclose(self) -> None:
        await self._client.aclose()

    async def analyze(
        self,
        system_prompt: str,
        user_prompt: str,
    ) -> str:
        """Call Gemini and return the raw JSON string of the response.

        Raises :class:`UpstreamError` on transport failures, timeouts, or
        non-2xx responses (after a single retry on transient failures).
        Schema/parse errors are left to the parser layer.
        """
        if self._settings.google_ai_api_key is None:
            raise UpstreamError("Gemini API key not configured.")

        url = f"{_GEMINI_BASE}/{self._settings.gemini_model}:generateContent"
        params = {"key": self._settings.google_ai_api_key.get_secret_value()}

        body: dict[str, Any] = {
            "systemInstruction": {"parts": [{"text": system_prompt}]},
            "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
            "generationConfig": {
                "temperature": 0.1,
                "responseMimeType": "application/json",
                "responseSchema": _RESPONSE_SCHEMA,
                "maxOutputTokens": 1024,
            },
        }

        last_err: Exception | None = None
        for attempt in (1, 2):
            try:
                resp = await self._client.post(url, params=params, json=body)
            except httpx.RequestError as e:
                last_err = e
                log.warning("gemini_request_error", attempt=attempt, error=str(e))
                continue

            if resp.status_code == 200:
                return _extract_text(resp.json())
            if 500 <= resp.status_code < 600 and attempt == 1:
                log.warning("gemini_5xx_retrying", status=resp.status_code)
                continue
            log.error("gemini_non_2xx", status=resp.status_code, body=resp.text[:500])
            raise UpstreamError(f"Gemini returned HTTP {resp.status_code}.")

        raise UpstreamError(f"Gemini request failed after retries: {last_err}")


def _extract_text(payload: dict[str, Any]) -> str:
    """Pull the model's text out of Gemini's verbose response shape."""
    try:
        candidates = payload["candidates"]
        parts = candidates[0]["content"]["parts"]
        text = parts[0]["text"]
    except (KeyError, IndexError, TypeError) as e:
        raise UpstreamError(f"Unexpected Gemini response shape: {e}") from e

    if not isinstance(text, str) or not text.strip():
        raise UpstreamError("Gemini returned empty text.")
    # Strict-schema mode means Gemini already returns valid JSON in `text`.
    # The parser layer validates it; we just hand off the string.
    return text


def build_user_prompt(
    request: AnalysisRequest,
    breed_context: str,
) -> str:
    """Render the per-request user-side message.

    The system prompt holds invariant rules + schema. The user prompt
    carries everything specific to the inbound request.
    """
    pet = request.pet
    pet_lines = [
        f"Species: {pet.species}",
        f"Name: {pet.name}",
    ]
    if pet.breed:
        pet_lines.append(f"Breed: {pet.breed}")
    if pet.age_years is not None:
        pet_lines.append(f"Age (years): {pet.age_years}")
    if pet.sex:
        pet_lines.append(f"Sex: {pet.sex}")
    if pet.weight_kg is not None:
        pet_lines.append(f"Weight (kg): {pet.weight_kg}")
    if pet.conditions:
        pet_lines.append(f"Known conditions: {', '.join(pet.conditions)}")

    blocks = ["### Pet", "\n".join(pet_lines)]
    if breed_context:
        blocks += ["### Breed risk context", breed_context]
    if request.text_description:
        blocks += ["### Owner's description", request.text_description]
    blocks += [
        "### Task",
        "Produce the JSON analysis per the schema. Be conservative; "
        "prefer MONITOR over NORMAL when uncertain.",
    ]
    return "\n\n".join(blocks)
