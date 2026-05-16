"""Shared request/response schemas.

The AI service exposes two endpoints:
- ``/health``  → ``HealthStatus``
- ``/analyze`` → ``AnalysisRequest`` in, ``AnalysisResult`` out

The schemas live in one module so that any consumer (orchestrator,
parser, router, edge function via mirrored TypeScript) can import a
single canonical name.

Discipline:
- All models are ``ConfigDict(extra="forbid")``. Drift between schema
  versions surfaces immediately rather than silently dropping fields.
- Enumerated fields use ``Literal`` types — the analyzer + JSON schema
  generation both benefit.
- No default values for the analysis result's *content* fields. We force
  the LLM (or the orchestrator's graceful-degradation path) to provide
  them explicitly.
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

# -----------------------------------------------------------------------------
# Health
# -----------------------------------------------------------------------------


class HealthStatus(BaseModel):
    """Minimal liveness/readiness payload."""

    model_config = ConfigDict(extra="forbid")

    status: Literal["ok"] = "ok"
    service: str = Field(default="pawdoc-ai")
    version: str
    environment: str
    timestamp: datetime


# -----------------------------------------------------------------------------
# Analyze — request
# -----------------------------------------------------------------------------


TriageLevel = Literal["EMERGENCY", "MONITOR", "NORMAL"]
InputType = Literal["photo", "video", "text"]
PetSpecies = Literal["dog", "cat", "rabbit", "bird", "reptile", "other"]
PetSex = Literal["male", "female", "unknown"]


class PetContext(BaseModel):
    """Pet metadata supplied by the edge function for prompt injection.

    Field-by-field rationale (when the answer isn't obvious):
    - ``user_id`` is **deliberately absent**. The AI service does not need
      it; the edge function holds it; the analysis row carries it. Reduces
      the AI service's PII blast radius.
    - ``conditions`` is a short list of known chronic conditions (e.g.,
      "diabetes", "arthritis"). Phase 1B passes an empty list; Phase 3
      populates from health_events history.
    """

    model_config = ConfigDict(extra="forbid")

    pet_id: str
    name: str
    species: PetSpecies
    breed: str | None = None
    age_years: float | None = Field(default=None, ge=0, le=30)
    sex: PetSex | None = None
    weight_kg: float | None = Field(default=None, gt=0)
    conditions: list[str] = Field(default_factory=list)


class AnalysisRequest(BaseModel):
    """Inbound /analyze request from the edge function.

    The edge function has already authenticated the user, verified pet
    ownership, and consumed quota. The AI service trusts this and runs
    the orchestration.
    """

    model_config = ConfigDict(extra="forbid")

    request_id: str
    pet: PetContext
    input_type: InputType
    input_storage_url: str | None = Field(
        default=None,
        description=(
            "Pre-signed Cloudflare R2 URL the AI service fetches for vision input. "
            "Required when input_type is 'photo' or 'video'."
        ),
    )
    text_description: str | None = Field(
        default=None,
        description="Free-text symptom description.",
    )


# -----------------------------------------------------------------------------
# Analyze — provider output (what Gemini/Claude return)
# -----------------------------------------------------------------------------


class AnalysisProviderOutput(BaseModel):
    """The structured output we coerce every LLM call into.

    This is the *content* schema. The orchestrator wraps it with metadata
    (model_used, tier_used, etc.) into ``AnalysisResult`` before responding.
    """

    model_config = ConfigDict(extra="forbid")

    triage_level: TriageLevel
    confidence: float = Field(ge=0.0, le=1.0)
    primary_concern: str = Field(min_length=10, max_length=500)
    visible_symptoms: list[str] = Field(default_factory=list, max_length=20)
    differential: list[str] = Field(default_factory=list, max_length=10)
    recommended_actions: list[str] = Field(min_length=1, max_length=10)
    urgency_timeframe: str = Field(min_length=3, max_length=120)


# -----------------------------------------------------------------------------
# Analyze — final result returned to the edge function
# -----------------------------------------------------------------------------


class AnalysisResult(BaseModel):
    """What ``/analyze`` returns. Persisted into ``analyses.full_response``.

    Metadata fields (``model_used``, ``tier_used``, ``ai_latency_ms``, etc.)
    are filled by the orchestrator. They reflect runtime behavior, not LLM
    output.
    """

    model_config = ConfigDict(extra="forbid")

    triage_level: TriageLevel
    confidence: float = Field(ge=0.0, le=1.0)
    primary_concern: str
    visible_symptoms: list[str]
    differential: list[str]
    recommended_actions: list[str]
    urgency_timeframe: str

    disclaimer_required: bool = True
    disclaimer_text: str = Field(
        default=(
            "PawDoc provides triage guidance, not a veterinary diagnosis. "
            "Always consult a licensed veterinarian for medical decisions."
        )
    )

    model_used: str
    tier_used: Literal[0, 1, 2, 3, 4] = Field(
        description=(
            "0 = graceful degradation; 1 = emergency keyword override; "
            "2 = Gemini Tier 2; 3 = Claude Tier 3; 4 = Claude Opus (Phase 2+)."
        )
    )
    emergency_override_applied: bool = False
    cross_verify_disagreement: bool = False
    ai_latency_ms: int = Field(ge=0)
    request_id: str
