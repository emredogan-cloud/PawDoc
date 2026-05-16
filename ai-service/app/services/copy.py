"""User-facing copy strings — the App Store tone surface.

Why this module exists
----------------------
Every string a pet owner sees on the result screen ultimately comes
from one of three places:

1. The LLM's free-text fields (``primary_concern``,
   ``recommended_actions``, ``urgency_timeframe``). System-prompt
   discipline keeps these on tone.
2. The orchestrator's deterministic fallbacks: emergency keyword
   override, graceful degradation. These bypass the model entirely.
3. The mobile result screen's hardcoded copy (headlines, CTA labels).
   Lives in Dart; outside this file.

Before Sprint B3 the (2) strings lived in three different places —
``services/safety.py``, ``services/orchestrator.py``, and the
Pydantic default in ``models/schemas.py``. That made an App Store
tone review a three-grep operation. This module consolidates them
so a reviewer can audit "what does the user see when our AI fails"
in one open file.

Tone invariants enforced by ``tests/test_copy.py``:

- No "diagnosis", "treatment", "cure", "guaranteed" anywhere.
- No alarmist amplifiers ("dying", "fatal", "you must").
- Every fallback ends with the message "see a vet" framing.
- Every string is short enough for the mobile result card (≤ 350
  chars).
"""

from __future__ import annotations


# ---------------------------------------------------------------------------
# Disclaimer
# ---------------------------------------------------------------------------
#
# Echoed on every analysis response (``AnalysisResult.disclaimer_text``).
# Mirrored verbatim in `mobile/lib/shared/widgets/disclaimer.dart`.
# Changing one without the other will fail the mobile compliance test.
CANONICAL_DISCLAIMER: str = (
    "PawDoc provides triage guidance, not a veterinary diagnosis. "
    "Always consult a licensed veterinarian for medical decisions."
)


# ---------------------------------------------------------------------------
# Graceful degradation (Tier 3 failure / below-confidence-floor)
# ---------------------------------------------------------------------------
#
# Returned when neither AI tier produced a usable response. The user
# sees calm "we couldn't be confident; please see a vet" wording rather
# than a technical failure message. Triage level locks to MONITOR with
# confidence 0.0 — the result card already flags low-confidence
# results via the "Limited analysis" callout in the mobile UI.
DEGRADATION_PRIMARY_CONCERN: str = (
    "We could not analyze this request with confidence. Please consult "
    "a veterinarian and describe the symptoms directly."
)

DEGRADATION_URGENCY: str = "Within 24 hours."

DEGRADATION_RECOMMENDED_ACTIONS: tuple[str, ...] = (
    "Contact your veterinarian within 24 hours.",
    "Take a clear photo of any visible symptoms for the vet visit.",
    "Note when symptoms started, severity, and any changes.",
)


def degradation_recommended_actions() -> list[str]:
    """Return a fresh list each call — the orchestrator owns the
    mutability of the returned model."""
    return list(DEGRADATION_RECOMMENDED_ACTIONS)


# ---------------------------------------------------------------------------
# Emergency keyword override
# ---------------------------------------------------------------------------
#
# Returned when the pre-AI keyword scan matched a critical phrase
# (``services/safety.py::EMERGENCY_KEYWORDS``). The model never runs;
# the user goes straight to "seek vet care immediately." App Store
# review safety: this avoids "treatment" framing — owner is told to
# stop at-home actions and head to the vet.
EMERGENCY_URGENCY: str = "Immediately."

EMERGENCY_FALLBACK_HEADLINE: str = (
    "We detected language consistent with a possible emergency. "
    "Seek vet care immediately."
)

EMERGENCY_RECOMMENDED_ACTIONS: tuple[str, ...] = (
    "Stop any at-home remedies or interventions.",
    "Contact your nearest 24h veterinary emergency clinic right now.",
    "If your pet is not breathing or is unresponsive, perform CPR while en route.",
    "Bring any suspected toxic substance packaging or photographs to the clinic.",
)


def emergency_recommended_actions() -> list[str]:
    return list(EMERGENCY_RECOMMENDED_ACTIONS)


def emergency_response_text(keyword: str | None) -> str:
    """The headline the user sees on an emergency override.

    Wraps the matched keyword in calm, action-oriented framing. Tests
    pin the exact substring "{keyword!r}" so a refactor that drops
    keyword echo into the message will fail.
    """
    if keyword:
        return (
            "We detected language consistent with a possible emergency "
            f"({keyword!r}). Please seek veterinary care immediately."
        )
    return EMERGENCY_FALLBACK_HEADLINE


# ---------------------------------------------------------------------------
# Tone-audit helpers — used by the test suite
# ---------------------------------------------------------------------------

#: Substrings we refuse in any user-visible copy. App Store medical-
#: device review trips on these; the App Store metadata audit
#: (Sprint A1) imposes the same constraint.
TONE_FORBIDDEN_SUBSTRINGS: tuple[str, ...] = (
    "diagnosis",
    "diagnose",
    "treatment",
    "treat",
    "cure",
    "guaranteed",
    "guarantee",
    "fatal",
    "dying",
)


def all_user_facing_strings() -> list[str]:
    """Return every string this module exposes to the result payload.

    Tests iterate over this list to enforce tone invariants. Keep
    additions strictly limited to strings users actually see — internal
    log lines, model_used identifiers, etc. do NOT belong here.
    """
    return [
        CANONICAL_DISCLAIMER,
        DEGRADATION_PRIMARY_CONCERN,
        DEGRADATION_URGENCY,
        EMERGENCY_FALLBACK_HEADLINE,
        EMERGENCY_URGENCY,
        *DEGRADATION_RECOMMENDED_ACTIONS,
        *EMERGENCY_RECOMMENDED_ACTIONS,
        # Keyword-substituted variants the user can actually see.
        emergency_response_text("seizure"),
        emergency_response_text(None),
    ]
