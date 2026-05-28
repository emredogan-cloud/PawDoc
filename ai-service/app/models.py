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
    text_description: str | None = None
    image_url: str | None = None  # short-lived signed R2 URL (Phase 1.2)
    # Video (Phase 3.2): short-lived signed R2 URLs for the client-extracted
    # keyframes (4–6). Empty for photo/text.
    frame_urls: list[str] = Field(default_factory=list)
    pet: PetContext
    # Set by the Edge Function when client-side quality checks were poor; feeds
    # the borderline-NORMAL re-check (CR #4).
    low_input_quality: bool = False
    # CR #11 (Phase 5.4): user's preferred locale ('en' default, 'de' for the
    # German launch). Drives the pre-AI emergency-override keyword set, so a
    # German "Krampfanfall" still bypasses the AI to EMERGENCY.
    locale: str = "en"


class JournalRequest(BaseModel):
    """Input for the /generate_journal endpoint (AI Health Journal, Phase 5.3).
    The Edge cron summarizes the pet's last 7 days into these compact entries so
    the prompt stays small + the cost predictable."""

    pet: PetContext
    week_start_date: str  # ISO date 'YYYY-MM-DD' (Monday of the week)
    analyses: list[dict] = Field(default_factory=list)  # {triage_level, primary_concern, created_at}
    events: list[dict] = Field(default_factory=list)  # {event_type, event_date, notes?}


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
