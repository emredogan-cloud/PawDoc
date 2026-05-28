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
#
# CR #11 (Phase 5.4): keywords are now keyed by BCP-47 language ('en', 'de').
# An unknown locale falls back to 'en' (safe — we never serve an empty keyword
# set). The `EMERGENCY_KEYWORDS` / `SPECIES_EMERGENCY_KEYWORDS` names are kept
# as aliases for the English lists so older parametrize tests and external
# callers stay green. KEEP IN SYNC with
# supabase/functions/_shared/emergency_keywords.mjs (the Edge Function uses the
# same locale-keyed mapping to bypass the paywall for emergencies).
EMERGENCY_KEYWORDS_BY_LOCALE: dict[str, list[str]] = {
    "en": [
        "not breathing", "stopped breathing", "can't breathe", "labored breathing",
        "blue gums", "grey gums", "pale gums",
        "seizure", "seizing", "convulsing",
        "collapse", "collapsed", "can't stand",
        "grapes", "xylitol", "rat poison", "antifreeze",
        "suspected poisoning", "ate something toxic",
        "hit by car", "severe bleeding",
        "broken bone", "compound fracture",
    ],
    # German (Deutsch). Lowercased here (substring match is case-insensitive on
    # the input). Includes common phrasing variants because over-inclusion is
    # the SAFE direction for a triage app.
    "de": [
        # Breathing.
        "atmet nicht", "hat aufgehört zu atmen", "kann nicht atmen", "atemnot",
        "schwere atmung", "atmet schwer",
        # Mucous-membrane color.
        "blaues zahnfleisch", "graues zahnfleisch", "blasses zahnfleisch",
        # Seizure / collapse / immobility.
        "krampfanfall", "krampft", "anfall", "konvulsionen", "zuckungen",
        "kollaps", "zusammengebrochen", "kann nicht stehen",
        # Toxins.
        "weintrauben", "trauben", "xylit", "xylitol",
        "rattengift", "frostschutzmittel", "frostschutz",
        "verdacht auf vergiftung", "vergiftet",
        "etwas giftiges gefressen", "etwas giftiges gegessen",
        # Trauma / bleeding / fracture.
        "vom auto angefahren", "angefahren", "starke blutung", "blutet stark",
        "knochenbruch", "gebrochener knochen", "offener bruch", "offene fraktur",
    ],
}
# Back-compat alias used by tests / imports already in the tree.
EMERGENCY_KEYWORDS: list[str] = EMERGENCY_KEYWORDS_BY_LOCALE["en"]

# Species-specific emergency triggers (Phase 5.1, localized in Phase 5.4).
# Layout: {locale: {species: [keywords]}}. These fire ONLY when the pet is of
# the matching species — e.g. "not eating" is an EMERGENCY for a rabbit/guinea
# pig (GI stasis) or a bird, but only a RISK_SIGNAL for a dog. KEEP IN SYNC
# with supabase/functions/_shared/emergency_keywords.mjs.
SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE: dict[str, dict[str, list[str]]] = {
    "en": {
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
    },
    "de": {
        # Kaninchen (rabbit).
        "rabbit": [
            "frisst nicht", "isst nicht", "frisst kein heu", "frisst kein futter",
            "kein kot", "keine köttel", "kein köttel", "keinen kot abgesetzt",
            "verstopfung", "trinkt nicht", "aufgebläht", "aufgeblähter bauch",
            "harter bauch", "kopfschiefhaltung", "schiefer kopf", "kippt den kopf",
            "magen-darm-stase", "darmstase", "bewegt sich nicht",
        ],
        # Meerschweinchen (guinea pig).
        "guinea_pig": [
            "frisst nicht", "isst nicht", "kein kot", "keine köttel",
            "trinkt nicht", "aufgebläht", "aufgeblähter bauch",
            "schwere atmung", "atmet schwer", "darmstase", "bewegt sich nicht",
        ],
        # Vogel (bird).
        "bird": [
            "aufgeplustert", "plustert sich auf", "sitzt am käfigboden",
            "auf dem käfigboden", "auf dem boden des käfigs", "schwanzwippen",
            "wippt mit dem schwanz", "atmet mit offenem schnabel",
            "öffnet den schnabel zum atmen", "frisst nicht",
            "vom ast gefallen", "vom sitzast gefallen", "sitzt nicht auf",
        ],
        # Reptil.
        "reptile": [
            "atmet mit offenem maul", "atmet mit offenem mund", "schnappt nach luft",
            "maulfäule", "prolaps", "reagiert nicht", "bewegt sich nicht",
        ],
    },
}
# Back-compat alias.
SPECIES_EMERGENCY_KEYWORDS: dict[str, list[str]] = SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE["en"]

# Supported locales (used by both keyword maps).
SUPPORTED_LOCALES: tuple[str, ...] = tuple(EMERGENCY_KEYWORDS_BY_LOCALE.keys())


def _norm_species(species: str | None) -> str:
    """Normalize a species token so 'guinea pig' / 'Guinea_Pig' / 'guinea_pig'
    all match the same key."""
    return (species or "").strip().lower().replace(" ", "_")


def _norm_locale(locale: str | None) -> str:
    """BCP-47 -> 2-letter primary tag, lowercased. Unknown locales fall back to
    'en' (the SAFE default — we never silently serve an empty keyword set)."""
    if not locale:
        return "en"
    code = locale.strip().lower().split("-")[0]
    return code if code in EMERGENCY_KEYWORDS_BY_LOCALE else "en"


# Risk signals that should prevent a too-easy NORMAL (CR #4).
RISK_SIGNAL_KEYWORDS: list[str] = [
    "vomit", "vomiting", "diarrhea", "blood", "bloody", "lethargic", "lethargy",
    "not eating", "won't eat", "limp", "limping", "swelling", "swollen",
    "pain", "crying", "whining", "trembling", "shaking", "wound", "discharge",
    "coughing", "wheezing", "straining", "won't drink",
]


def check_emergency_override(
    text: str | None,
    species: str | None = None,
    locale: str | None = "en",
) -> str | None:
    """Return the first matching emergency keyword, or None. Evaluates the GLOBAL
    keywords (all species) and then the SPECIES-SPECIFIC keywords for the pet's
    species (Phase 5.1), in the requested locale (Phase 5.4 / CR #11). An
    unknown locale falls back to English so we never silently lose coverage."""
    if not text:
        return None
    lowered = text.lower()
    lkey = _norm_locale(locale)
    for keyword in EMERGENCY_KEYWORDS_BY_LOCALE[lkey]:
        if keyword in lowered:
            return keyword
    species_map = SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE.get(lkey, {})
    for keyword in species_map.get(_norm_species(species), ()):
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
