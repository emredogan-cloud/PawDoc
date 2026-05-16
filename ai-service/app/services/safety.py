"""Hardcoded emergency keyword detection.

This is the SAFETY-CRITICAL path. It runs BEFORE any LLM call. If a keyword
matches, the orchestrator returns an EMERGENCY classification immediately —
no AI is involved, no quota is charged.

The list is authoritative; the edge function carries a mirror in
``supabase/functions/_shared/emergency.ts`` for the quota-bypass decision.
Drift between the two files is acceptable for quota purposes but should be
kept in sync; a CI step compares the two.

Why hardcoded:
- Models can hallucinate or misclassify in any direction. A keyword path
  guarantees that the most dangerous queries take the safest path.
- The list is short, English-only, and well-understood.
- Localisation will require per-locale keyword lists in a later phase.

Why substring (not word-boundary):
- We accept false positives in the EMERGENCY direction — over-triage is
  safer than missing.
- "seizing" matches "seizing up" — both should trigger EMERGENCY.
- We do NOT match plain "blue" or "gum" alone; the keyword is the multi-
  word phrase.
"""

from __future__ import annotations

from dataclasses import dataclass

# IMPORTANT: roadmap §9 — these are the hardcoded triggers. Adding or removing
# items here must be coordinated with the edge function mirror.
EMERGENCY_KEYWORDS: tuple[str, ...] = (
    "not breathing",
    "stopped breathing",
    "can't breathe",
    "cant breathe",
    "labored breathing",
    "blue gums",
    "grey gums",
    "gray gums",
    "pale gums",
    "seizure",
    "seizing",
    "convulsing",
    "collapse",
    "collapsed",
    "can't stand",
    "cant stand",
    "grapes",
    "xylitol",
    "rat poison",
    "antifreeze",
    "suspected poisoning",
    "ate something toxic",
    "hit by car",
    "severe bleeding",
    "broken bone",
    "compound fracture",
)


@dataclass(frozen=True, slots=True)
class EmergencyMatch:
    matched: bool
    keyword: str | None

    @classmethod
    def none(cls) -> EmergencyMatch:
        return cls(matched=False, keyword=None)


def check_emergency_override(text: str | None) -> EmergencyMatch:
    """Scan free text for an emergency keyword.

    Returns the FIRST match found (deterministic). Case- and whitespace-
    insensitive. Returns no match when ``text`` is None/empty.
    """
    if not text:
        return EmergencyMatch.none()
    lowered = text.lower()
    for kw in EMERGENCY_KEYWORDS:
        if kw in lowered:
            return EmergencyMatch(matched=True, keyword=kw)
    return EmergencyMatch.none()


def emergency_response_text(keyword: str | None) -> str:
    """The user-facing primary_concern returned for an override match.

    Deliberately calm and action-oriented. The mobile UI shows full
    escalation triggers; this string is the headline.
    """
    if keyword:
        return (
            "We detected language consistent with a possible emergency "
            f"({keyword!r}). Please seek veterinary care immediately."
        )
    return "We detected language consistent with a possible emergency. Seek vet care immediately."


def emergency_recommended_actions() -> list[str]:
    # App Store review safety: avoid "treatment" framing (medical-device
    # trigger). The intent — stop trying to handle it yourself, go to a
    # vet — is preserved.
    return [
        "Stop any at-home remedies or interventions.",
        "Contact your nearest 24h veterinary emergency clinic right now.",
        "If your pet is not breathing or is unresponsive, perform CPR while en route.",
        "Bring any suspected toxic substance packaging or photographs to the clinic.",
    ]
