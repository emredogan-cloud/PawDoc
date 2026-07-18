"""Pydantic models — including the `AnalysisResult` binding of the frozen
cross-language contract (docs/contracts/ANALYSIS_RESULT.md, CR #16)."""
from __future__ import annotations

import json
from enum import Enum

from pydantic import BaseModel, Field, ValidationError


class ActionLevel(str, Enum):
    """The action ladder (contract v2). There is deliberately NO terminal
    "everything is fine" state: the lowest rung prescribes what to watch for
    and when to re-check — the app never owns the reassurance. See
    docs/contracts/ANALYSIS_RESULT.md."""

    GET_HELP_NOW = "GET_HELP_NOW"          # life/serious-harm signs — go now
    CALL_TODAY = "CALL_TODAY"              # speak to a vet practice today
    BOOK_VISIT = "BOOK_VISIT"              # routine appointment in coming days
    WATCH_AND_RECHECK = "WATCH_AND_RECHECK"  # lowest rung: watch + re-check




class PetContext(BaseModel):
    species: str
    breed: str | None = None
    age_years: float | None = None
    sex: str | None = None
    weight_kg: float | None = None
    prior_history: list[str] = Field(default_factory=list)


class AnalyzeRequest(BaseModel):
    input_type: str  # photo | text
    # GAP-A4: bound the request so a megabyte prompt / frame flood can't pin the
    # service or run up cost. Over-cap input -> 422 (Pydantic ValidationError).
    text_description: str | None = Field(default=None, max_length=4000)
    image_url: str | None = None  # short-lived signed R2 URL (Phase 1.2)
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


class AnalysisResult(BaseModel):
    """Frozen contract v2. JSON keys ARE these field names (snake_case).

    v2 (evolution reframe): the diagnostic surface is GONE by design —
    no `differential` (a ranked differential is the diagnostic act), no
    disease names in any field, and no output that terminates without an
    action and a timeframe. `confidence` is INTERNAL routing/storage only
    and must never be rendered to the user."""

    action: ActionLevel
    confidence: float = Field(ge=0.0, le=1.0)
    # Plain-language description of what was observed/reported — NEVER a
    # suspected condition. "a swollen, firm belly", not "suspected bloat (GDV)".
    observation: str
    visible_symptoms: list[str] = Field(default_factory=list)
    # Educational: what a veterinarian typically assesses for THIS KIND of
    # presentation (general knowledge about the presentation class — never
    # findings or condition names about this specific animal).
    vets_look_for: list[str] = Field(default_factory=list)
    # Signs that mean the owner should escalate sooner than the chosen rung.
    watch_for: list[str] = Field(default_factory=list)
    recommended_actions: list[str] = Field(default_factory=list)
    urgency_timeframe: str
    # Hours until a re-check makes sense (drives the client's re-check
    # reminder CTA). REQUIRED semantics: WATCH_AND_RECHECK must carry one.
    recheck_hours: int | None = Field(default=None, ge=1, le=336)
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
