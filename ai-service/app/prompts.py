"""System prompt v1 with anti-hallucination guards (Phase 1.3 deliverable).

Phase 6.1 — Personalization. The prompt is now split into three parts so we
can cache the static + per-pet pieces and pay tokens only for the dynamic
per-check text:

  (1) `SYSTEM_PROMPT_V1`             — fully static safety contract. ALWAYS cached.
  (2) `build_personalization_block`  — pet profile + recent history. Per-pet,
                                       stable within a session ⇒ second cache
                                       breakpoint when the provider supports it
                                       (Anthropic ephemeral cache, 5-min TTL).
  (3) `build_user_prompt`            — owner's current symptom text + input
                                       type. Always dynamic; never cached.
"""
from __future__ import annotations

from .models import AnalyzeRequest, PetContext

SYSTEM_PROMPT_V1 = """You are PawDoc, a veterinary triage assistant for pet owners.

You provide INFORMATION to help owners decide whether and how urgently to seek
veterinary care. You are NOT a veterinarian and you do NOT diagnose.

Triage levels (choose exactly one):
- EMERGENCY: needs veterinary attention now / within hours.
- MONITOR: watch closely; see a vet if it worsens or persists.
- NORMAL: no concerning signs in the provided input.

Anti-hallucination rules (critical):
- Describe ONLY what is visible in the image/video or stated in the text.
- NEVER invent symptoms, breeds, measurements, or history that were not provided.
- If the input is insufficient or ambiguous, LOWER your confidence accordingly —
  do not guess to seem helpful.
- When in doubt between two levels, choose the MORE cautious one.
- Keep recommendations general and safe; never prescribe specific drug doses.

Tone: calm, clear, compassionate, plain language. No alarmism, no false reassurance.

Return ONLY a JSON object matching this schema (no prose, no markdown):
{
  "triage_level": "EMERGENCY|MONITOR|NORMAL",
  "confidence": 0.0-1.0,
  "primary_concern": "one short sentence",
  "visible_symptoms": ["..."],
  "differential": ["most to least likely"],
  "recommended_actions": ["ordered steps"],
  "urgency_timeframe": "e.g. immediately | within 24 hours | routine",
  "disclaimer_required": true
}"""


# Species-specific clinical context (Phase 5.1). Injected into the personalization
# block so the model applies the right red-flag thresholds — exotics decompensate
# fast and hide illness, so signs that are "monitor" in a dog are urgent in them.
SPECIES_GUIDANCE: dict[str, str] = {
    "rabbit": (
        "Species note (rabbit): rabbits are prey animals that hide illness. GI "
        "stasis is a TRUE EMERGENCY — not eating, few/no fecal droppings, or a "
        "bloated/hard belly needs urgent care (not 'monitor'). Head tilt, labored "
        "breathing, or sudden lethargy are also urgent. Never advise withholding food."
    ),
    "guinea_pig": (
        "Species note (guinea pig): like rabbits, prone to GI stasis — not eating or "
        "not passing droppings is urgent. Respiratory-fragile (labored breathing is an "
        "emergency). They cannot synthesize vitamin C."
    ),
    "bird": (
        "Species note (bird): birds mask illness extremely well; visible signs often "
        "mean the bird is already critically ill. Treat as urgent: fluffed/puffed "
        "feathers, sitting on the cage floor, tail-bobbing, open-mouth breathing, not "
        "eating, or any sudden change. Keep away from fumes (non-stick cookware, smoke)."
    ),
    "reptile": (
        "Species note (reptile): ectotherms — many problems trace to husbandry "
        "(temperature, UVB, humidity). Urgent signs: open-mouth breathing (possible "
        "respiratory infection), mouth rot, prolapse, or unresponsiveness. Reduced "
        "appetite can be normal during brumation, so weigh it alongside other signs."
    ),
}


def species_guidance(species: str) -> str:
    """Species-specific clinical notes; '' for dog/cat/other."""
    key = species.strip().lower().replace(" ", "_")
    return SPECIES_GUIDANCE.get(key, "")


# Phase 6.1 — bound the prompt size. Recent history is a moat, not an essay:
# the most relevant signal is the last few items. These caps keep token cost
# predictable even for power users with rich timelines.
RECENT_ANALYSES_CAP = 10
RECENT_EVENTS_CAP = 10


def _pet_profile_lines(pet: PetContext) -> list[str]:
    lines = [f"Species: {pet.species}"]
    if pet.breed:
        lines.append(f"Breed: {pet.breed}")
    if pet.age_years is not None:
        lines.append(f"Age (years): {pet.age_years}")
    if pet.sex:
        lines.append(f"Sex: {pet.sex}")
    if pet.weight_kg is not None:
        lines.append(f"Weight (kg): {pet.weight_kg}")
    if pet.prior_history:
        lines.append("Prior history: " + "; ".join(pet.prior_history))
    return lines


def _format_recent_analyses(rows: list[dict]) -> list[str]:
    """Compact, per-row summaries — no full payloads, no PII."""
    out: list[str] = []
    for r in rows[:RECENT_ANALYSES_CAP]:
        # The Edge ships {triage_level, primary_concern, created_at} — be
        # tolerant of any missing field rather than failing the whole call.
        triage = (r.get("triage_level") or "").upper()
        date = (r.get("created_at") or "")[:10] or "earlier"
        concern = r.get("primary_concern") or "(no concern recorded)"
        out.append(f"  - [{date}] {triage}: {concern}")
    return out


def _format_recent_events(rows: list[dict]) -> list[str]:
    out: list[str] = []
    for r in rows[:RECENT_EVENTS_CAP]:
        kind = r.get("event_type") or "event"
        date = (r.get("event_date") or "")[:10] or "earlier"
        notes = r.get("notes")
        out.append(
            f"  - [{date}] {kind}" + (f": {notes}" if notes else "")
        )
    return out


def build_personalization_block(
    pet: PetContext,
    recent_analyses: list[dict] | None = None,
    recent_events: list[dict] | None = None,
) -> str:
    """Per-pet, history-aware context for the model. Stable within a session ⇒
    placed in the provider's cache-able portion of the prompt (Anthropic's
    `cache_control: ephemeral` block #2). Adapts to whatever the caller has —
    a pet with no history still gets a sensible profile block.
    """
    parts = ["Pet profile:", *_pet_profile_lines(pet)]
    guidance = species_guidance(pet.species)
    if guidance:
        parts.append("")
        parts.append(guidance)

    # Recent analyses: newest first if the caller sorted them; we don't re-sort
    # (the Edge already orders DESC). Empty section is omitted entirely.
    if recent_analyses:
        parts.append("")
        parts.append("Recent analyses (last 30 days, newest first):")
        parts.extend(_format_recent_analyses(recent_analyses))

    if recent_events:
        parts.append("")
        parts.append("Recent health events (last 30 days, newest first):")
        parts.extend(_format_recent_events(recent_events))

    if recent_analyses or recent_events:
        parts.append("")
        parts.append(
            "Treat the history as background context, NOT as ground truth — "
            "weigh it against the current input, and never invent details not "
            "stated here."
        )

    return "\n".join(parts)


def build_user_prompt(request: AnalyzeRequest) -> str:
    """Dynamic per-check portion — owner's current description + input type.
    Phase 6.1: the pet profile + history moved to `build_personalization_block`
    (cache-friendly); this string is the only part that varies request-to-request.
    """
    lines: list[str] = [f"Input type: {request.input_type}"]
    if request.text_description:
        lines.append(f"Owner description: {request.text_description}")
    if request.frame_urls:
        lines.append(
            f"{len(request.frame_urls)} video keyframes are provided (sampled across "
            "the clip) for visual assessment; reason over the sequence as one event."
        )
    elif request.image_url:
        lines.append("An image is provided for visual assessment.")
    return "\n".join(lines)
