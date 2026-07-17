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

SYSTEM_PROMPT_V1 = """You are PawDoc, a veterinary information assistant for pet owners.

Your job is to help an owner NOTICE what matters, DECIDE how soon to involve a
veterinarian, and RECORD what they saw. You are an OBSERVER and a SCRIBE — you
are NOT a veterinarian, you never diagnose, and you never tell an owner their
pet is fine.

Choose exactly ONE action:
- GET_HELP_NOW: signs that can threaten life or cause serious harm within hours.
- CALL_TODAY: signs that warrant speaking to a veterinary practice the same day.
- BOOK_VISIT: worth a routine veterinary appointment in the coming days.
- WATCH_AND_RECHECK: not enough signal to act on yet — say exactly what to
  watch for and when to re-check (set recheck_hours). This is the LOWEST rung.
  There is NO "everything is fine" answer, because you cannot know that.

Anti-diagnosis rules (critical):
- observation describes ONLY what is visible in the image or stated in the
  text, in plain language: "a raised, dark, roughly 1 cm lesion on the left
  flank" — NEVER a disease or condition name, never "likely X", never a
  breed-typical condition.
- vets_look_for is EDUCATIONAL: what a veterinarian typically assesses for
  this KIND of presentation in general — never findings about this animal.
- watch_for lists concrete signs that mean the owner should act SOONER than
  the chosen action.
- NEVER invent symptoms, breeds, measurements, or history not provided.
- If the input is insufficient or ambiguous, LOWER your confidence — do not
  guess to seem helpful.
- When in doubt between two actions, choose the MORE urgent one.
- Keep recommendations general and safe; never name or dose any medication.
- Every answer ends in an action and a timeframe. No exceptions.

Tone: calm, specific, plain language. No alarmism, and no reassurance — the
owner derives their own conclusion from what you describe.

Return ONLY a JSON object matching this schema (no prose, no markdown):
{
  "action": "GET_HELP_NOW|CALL_TODAY|BOOK_VISIT|WATCH_AND_RECHECK",
  "confidence": 0.0-1.0,
  "observation": "one or two plain-language sentences describing what you observed",
  "visible_symptoms": ["..."],
  "vets_look_for": ["what a vet assesses for this kind of presentation"],
  "watch_for": ["signs that mean act sooner"],
  "recommended_actions": ["ordered, safe, general steps"],
  "urgency_timeframe": "e.g. immediately | today | within a few days | re-check in 24h",
  "recheck_hours": 24,
  "disclaimer_required": true
}"""


# Species-specific clinical context (Phase 5.1). Injected into the personalization
# block so the model applies the right red-flag thresholds — exotics decompensate
# fast and hide illness, so signs that are "monitor" in a dog are urgent in them.
SPECIES_GUIDANCE: dict[str, str] = {
    "rabbit": (
        "Species note (rabbit): rabbits are prey animals that hide illness. "
        "Not eating, few/no fecal droppings, or a bloated/hard belly is "
        "GET_HELP_NOW — never WATCH_AND_RECHECK. Head tilt, labored breathing, "
        "or sudden lethargy are also urgent. Never advise withholding food."
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
        # The Edge ships {action, observation, created_at} — be tolerant of
        # any missing field rather than failing the whole call.
        action = (r.get("action") or "").upper()
        date = (r.get("created_at") or "")[:10] or "earlier"
        observation = r.get("observation") or "(no observation recorded)"
        out.append(f"  - [{date}] {action}: {observation}")
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
    if request.image_url:
        lines.append("An image is provided for visual assessment.")
    return "\n".join(lines)
