"""Pydantic models — including the `AnalysisResult` binding of the frozen
cross-language contract (docs/contracts/ANALYSIS_RESULT.md, CR #16)."""
from __future__ import annotations

import json
from enum import Enum

from pydantic import BaseModel, Field, ValidationError


class TriageLevel(str, Enum):
    EMERGENCY = "EMERGENCY"
    MONITOR = "MONITOR"
    NORMAL = "NORMAL"


class PetContext(BaseModel):
    species: str
    breed: str | None = None
    age_years: float | None = None
    sex: str | None = None
    weight_kg: float | None = None
    prior_history: list[str] = Field(default_factory=list)


class AnalyzeRequest(BaseModel):
    input_type: str  # photo | video | text
    # GAP-A4: bound the request so a megabyte prompt / frame flood can't pin the
    # service or run up cost. Over-cap input -> 422 (Pydantic ValidationError).
    text_description: str | None = Field(default=None, max_length=4000)
    image_url: str | None = None  # short-lived signed R2 URL (Phase 1.2)
    # Video (Phase 3.2): short-lived signed R2 URLs for the client-extracted
    # keyframes (4–6). Empty for photo/text. Capped at 6 (GAP-A4).
    frame_urls: list[str] = Field(default_factory=list, max_length=6)
    pet: PetContext
    # Set by the Edge Function when client-side quality checks were poor; feeds
    # the borderline-NORMAL re-check (CR #4).
    low_input_quality: bool = False
    # CR #11 (Phase 5.4): user's preferred locale ('en' default, 'de' for the
    # German launch). Drives the pre-AI emergency-override keyword set, so a
    # German "Krampfanfall" still bypasses the AI to EMERGENCY.
    locale: str = "en"
    # Phase 6.1 — personalization context. The Edge Function fetches the pet's
    # last 30 days of analyses + health events and ships compact summaries here
    # (no full payloads — keeps the prompt small and the cost bounded). Both
    # default to an empty list so older callers / tests continue to work.
    recent_analyses: list[dict] = Field(default_factory=list)
    recent_events: list[dict] = Field(default_factory=list)


class EmbedRequest(BaseModel):
    """Input for the /embed endpoint (semantic cache, Phase 3.2)."""

    text_description: str | None = None
    pet: PetContext


class AnalysisResult(BaseModel):
    """Frozen contract. JSON keys ARE these field names (snake_case)."""

    triage_level: TriageLevel
    confidence: float = Field(ge=0.0, le=1.0)
    primary_concern: str
    visible_symptoms: list[str] = Field(default_factory=list)
    differential: list[str] = Field(default_factory=list)
    recommended_actions: list[str] = Field(default_factory=list)
    urgency_timeframe: str
    disclaimer_required: bool = True


class AnalysisParseError(ValueError):
    """Raised when an AI response is malformed JSON or off-schema. The pipeline
    rejects + logs these and retries / degrades — never passes them through."""


def parse_analysis_result(raw: str | dict) -> AnalysisResult:
    """Parse a model response into an AnalysisResult, distinguishing malformed
    JSON from off-schema content so both can be rejected and logged."""
    if isinstance(raw, str):
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise AnalysisParseError(f"malformed JSON: {exc}") from exc
    elif isinstance(raw, dict):
        data = raw
    else:
        raise AnalysisParseError(f"unsupported payload type: {type(raw)!r}")

    try:
        return AnalysisResult.model_validate(data)
    except ValidationError as exc:
        raise AnalysisParseError(f"off-schema response: {exc}") from exc
