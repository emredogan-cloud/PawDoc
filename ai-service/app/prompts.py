"""System prompt v1 with anti-hallucination guards (Phase 1.3 deliverable)."""
from __future__ import annotations

from .models import AnalyzeRequest

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


# Species-specific clinical context (Phase 5.1). Injected into the user prompt so
# the model applies the right red-flag thresholds — exotics decompensate fast and
# hide illness, so signs that are "monitor" in a dog are urgent in them.
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
    """Species-specific clinical notes for the prompt; '' for dog/cat/other."""
    key = species.strip().lower().replace(" ", "_")
    return SPECIES_GUIDANCE.get(key, "")


def build_user_prompt(request: AnalyzeRequest) -> str:
    """Inject pet context (species, breed, age, sex, weight, prior history) so
    the model can personalize — without fabricating anything not given."""
    pet = request.pet
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
    if request.text_description:
        lines.append(f"Owner description: {request.text_description}")
    lines.append(f"Input type: {request.input_type}")
    if request.frame_urls:
        lines.append(
            f"{len(request.frame_urls)} video keyframes are provided (sampled across "
            "the clip) for visual assessment; reason over the sequence as one event."
        )
    elif request.image_url:
        lines.append("An image is provided for visual assessment.")
    guidance = species_guidance(pet.species)
    if guidance:
        lines.append(guidance)
    return "\n".join(lines)
