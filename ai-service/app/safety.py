"""Hardcoded safety layer — never AI-dependent.

- Emergency override: runs BEFORE any AI call; if any keyword matches, the
  result is EMERGENCY regardless of model output (roadmap §Emergency Override).
- Borderline-NORMAL re-check (CR #4): the stated #1 business risk is a viral
  false-negative, yet the source pipeline only double-checks EMERGENCY. This
  flags NORMAL results that carry risk signals so the pipeline escalates to
  Tier 3 or biases to MONITOR.
"""
from __future__ import annotations

from .models import AnalysisResult, AnalyzeRequest, TriageLevel

# Verbatim from the source roadmap (23 keywords; the decomposed roadmap's "14"
# undercounts — using the authoritative source list). Substring match errs
# toward over-triage (false positive), the SAFE direction for a triage product.
# NOTE (CR #11, deferred to localization phases 5.4/8.3): this is English-only
# and substring-matched; localize per supported locale before non-English launch.
EMERGENCY_KEYWORDS: list[str] = [
    "not breathing", "stopped breathing", "can't breathe", "labored breathing",
    "blue gums", "grey gums", "pale gums",
    "seizure", "seizing", "convulsing",
    "collapse", "collapsed", "can't stand",
    "grapes", "xylitol", "rat poison", "antifreeze",
    "suspected poisoning", "ate something toxic",
    "hit by car", "severe bleeding",
    "broken bone", "compound fracture",
]

# Species-specific emergency triggers (Phase 5.1). These fire the override ONLY
# when the pet is of the matching species — e.g. "not eating" is an EMERGENCY for
# a rabbit/guinea pig (GI stasis) or a bird (prey animals hide illness until
# critical), but for a dog it is only a RISK_SIGNAL (monitor). Keys are
# normalized species (see _norm_species). Err toward over-triage = the SAFE
# direction. KEEP IN SYNC with supabase/functions/_shared/emergency_keywords.mjs
# (the Edge Function uses the same list to bypass the paywall for emergencies).
SPECIES_EMERGENCY_KEYWORDS: dict[str, list[str]] = {
    # Rabbits: GI stasis is a true emergency; they hide illness as prey animals.
    "rabbit": [
        "not eating", "won't eat", "stopped eating", "not pooping", "no poop",
        "no droppings", "not drinking", "won't drink", "bloated", "hard belly",
        "head tilt", "tilting head", "gi stasis", "stasis", "not moving",
    ],
    # Guinea pigs: same GI-stasis physiology + respiratory fragility.
    "guinea_pig": [
        "not eating", "won't eat", "stopped eating", "not pooping", "no poop",
        "not drinking", "won't drink", "bloated", "gi stasis", "stasis",
        "labored breathing", "not moving",
    ],
    # Birds: mask illness extremely well — visible signs often mean critical.
    "bird": [
        "fluffed", "fluffed up", "puffed", "puffed up", "bottom of the cage",
        "on the cage floor", "sitting on the bottom", "tail bobbing",
        "open mouth breathing", "open-mouth breathing", "not eating", "won't eat",
        "fell off perch", "not perching",
    ],
    # Reptiles: temperature-dependent; reduced appetite can be normal during
    # brumation, so this set is deliberately conservative (clear danger signs).
    "reptile": [
        "open mouth breathing", "open-mouth breathing", "mouth rot", "prolapse",
        "unresponsive", "not moving", "gasping",
    ],
}


def _norm_species(species: str | None) -> str:
    """Normalize a species token so 'guinea pig' / 'Guinea_Pig' / 'guinea_pig'
    all match the same key."""
    return (species or "").strip().lower().replace(" ", "_")


# Risk signals that should prevent a too-easy NORMAL (CR #4).
RISK_SIGNAL_KEYWORDS: list[str] = [
    "vomit", "vomiting", "diarrhea", "blood", "bloody", "lethargic", "lethargy",
    "not eating", "won't eat", "limp", "limping", "swelling", "swollen",
    "pain", "crying", "whining", "trembling", "shaking", "wound", "discharge",
    "coughing", "wheezing", "straining", "won't drink",
]


def check_emergency_override(text: str | None, species: str | None = None) -> str | None:
    """Return the first matching emergency keyword, or None. Evaluates the GLOBAL
    keywords (all species) and then the SPECIES-SPECIFIC keywords for the pet's
    species (Phase 5.1) — so e.g. "not eating" overrides to EMERGENCY for a
    rabbit but not for a dog."""
    if not text:
        return None
    lowered = text.lower()
    for keyword in EMERGENCY_KEYWORDS:
        if keyword in lowered:
            return keyword
    for keyword in SPECIES_EMERGENCY_KEYWORDS.get(_norm_species(species), ()):
        if keyword in lowered:
            return keyword
    return None


def emergency_override_result(matched_keyword: str) -> AnalysisResult:
    """The fixed EMERGENCY result returned when the override fires."""
    return AnalysisResult(
        triage_level=TriageLevel.EMERGENCY,
        confidence=1.0,
        primary_concern=f"Emergency indicator detected: '{matched_keyword}'.",
        visible_symptoms=[],
        differential=[],
        recommended_actions=[
            "Contact an emergency veterinarian or animal poison control now.",
            "Do not wait for further analysis.",
        ],
        urgency_timeframe="immediately",
        disclaimer_required=True,
    )


def _text_for_signals(request: AnalyzeRequest) -> str:
    parts = [request.text_description or ""]
    parts.extend(request.pet.prior_history)
    return " ".join(parts).lower()


def has_risk_signals(request: AnalyzeRequest) -> bool:
    text = _text_for_signals(request)
    return any(signal in text for signal in RISK_SIGNAL_KEYWORDS)


def is_sensitive_pet(request: AnalyzeRequest) -> bool:
    """Very young/old pets and fragile exotics warrant extra caution."""
    age = request.pet.age_years
    if age is not None and (age < 1 or age >= 10):
        return True
    return _norm_species(request.pet.species) in {"rabbit", "bird", "reptile", "guinea_pig"}


def needs_normal_recheck(result: AnalysisResult, request: AnalyzeRequest) -> bool:
    """CR #4: a NORMAL result is suspicious if risk signals are present, the
    input was low quality, or the pet is sensitive. Such results should be
    escalated to Tier 3 (if not already) or biased to MONITOR."""
    if result.triage_level is not TriageLevel.NORMAL:
        return False
    return has_risk_signals(request) or request.low_input_quality or is_sensitive_pet(request)


def bias_to_monitor(result: AnalysisResult, reason: str) -> AnalysisResult:
    """Downgrade an unsafe NORMAL to MONITOR (CR #4 fallback when Tier 3 still
    says NORMAL but risk signals remain)."""
    return result.model_copy(
        update={
            "triage_level": TriageLevel.MONITOR,
            "primary_concern": result.primary_concern,
            "recommended_actions": [
                f"Monitor closely — {reason}.",
                *result.recommended_actions,
                "If symptoms worsen or persist, contact your veterinarian.",
            ],
            "disclaimer_required": True,
        }
    )
