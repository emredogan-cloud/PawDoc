"""Phase 6.2 — Outcome Feedback Loop training-dataset export.

Pure data-shaping for the moat-seed JSONL dataset. The PII-strip logic is
isolated here so it's unit-tested independently of any HTTP transport.

CRITICAL DATA RULE (Phase 6.2): the exported records MUST NOT carry:
  - any user id, pet id, analysis id, or feedback id
  - any IP / coordinates / device identifiers
  - any R2 storage key (which is signed but still a stable identifier)
  - the user's email, RevenueCat id, OneSignal player id, etc.

The exported records ARE allowed to carry the symptom text. The text is the
single highest-value signal for fine-tuning, and it does not directly identify
a user — though it MAY contain a pet name. Pet names are NOT user-identifying
PII and are useful linguistic context (the model needs to know "Buddy" refers
to the patient); a separate scrub pass before any external release is the
founder's call (e.g. an NER step). Documented in the script header.
"""
from __future__ import annotations

import json
from typing import Any, Iterable

# Keys we MAY emit. Anything else is dropped silently — this is a positive
# allowlist so an upstream schema change can't silently start leaking new PII.
CONTEXT_ALLOWED = {"species", "breed", "age_years", "input_type", "symptom_text"}
AI_ALLOWED = {"triage_level", "primary_concern", "confidence", "tier_used",
              "override_applied"}
OUTCOME_ALLOWED = {"user_outcome", "user_rating", "days_to_feedback"}


def _classify_signal(triage_level: str | None, outcome: str | None) -> str | None:
    """Mirror of the SQL view's CASE — kept in sync so the export carries the
    same FP/FN/TP/TN label the dashboards show."""
    if not triage_level or not outcome:
        return None
    if triage_level == "EMERGENCY" and outcome in ("vet_said_nothing", "resolved_on_own"):
        return "false_positive_proxy"
    if triage_level == "NORMAL" and outcome == "vet_confirmed":
        return "false_negative_proxy"
    if triage_level == "EMERGENCY" and outcome == "vet_confirmed":
        return "true_positive_proxy"
    if triage_level == "NORMAL" and outcome in ("vet_said_nothing", "resolved_on_own"):
        return "true_negative_proxy"
    return None


def _years_between(start_iso: str | None, end_iso: str | None) -> float | None:
    if not start_iso or not end_iso:
        return None
    try:
        # tolerant of "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM:SSZ"; never raises.
        from datetime import datetime
        s = datetime.fromisoformat(start_iso.replace("Z", "+00:00"))
        e = datetime.fromisoformat(end_iso.replace("Z", "+00:00"))
        return round((e - s).total_seconds() / 86400.0, 2)
    except Exception:  # noqa: BLE001
        return None


def _age_years(birth_date_iso: str | None, analyzed_at_iso: str | None) -> float | None:
    """Age (years) at the time of the analysis (NOT the time of export — so
    dataset samples taken at different times stay comparable). Birth date is
    a date string (YYYY-MM-DD); analyzed_at may include a time/TZ. Mixing
    naive and aware datetimes raises, so we collapse both to dates."""
    if not birth_date_iso or not analyzed_at_iso:
        return None
    try:
        from datetime import date
        # date.fromisoformat accepts "YYYY-MM-DD" — slice the analyzed_at to
        # drop any time/TZ part defensively.
        birth = date.fromisoformat(birth_date_iso[:10])
        when = date.fromisoformat(analyzed_at_iso[:10])
        return round((when - birth).days / 365.25, 1)
    except Exception:  # noqa: BLE001
        return None


def to_training_record(row: dict[str, Any]) -> dict[str, Any] | None:
    """Project a joined analyses+pets+analysis_feedback row into one training
    JSONL record. Returns None when the row has no outcome (the only rows
    useful for fine-tuning are those with a labeled outcome).

    Expected input shape (matches the PostgREST embed in
    `scripts/export-training-dataset.py`):

      {
        "triage_level": "EMERGENCY",
        "primary_concern": "...",
        "confidence_score": 0.83,
        "tier_used": 3,
        "emergency_override_applied": false,
        "input_type": "text",
        "text_description": "owner's symptom text",
        "created_at": "2026-05-20T10:00:00Z",
        "pet":             { "species": "dog", "breed": "Labrador", "birth_date": "2021-06-01" },
        "analysis_feedback": [{ "outcome": "vet_confirmed", "rating": 4, "created_at": "...Z" }],
      }
    """
    fb_list = row.get("analysis_feedback") or []
    if not fb_list:
        return None
    feedback = fb_list[0]
    outcome = feedback.get("outcome")
    if not outcome:
        return None

    pet = row.get("pet") or {}
    context = {
        "species": pet.get("species"),
        "breed": pet.get("breed"),
        "age_years": _age_years(pet.get("birth_date"), row.get("created_at")),
        "input_type": row.get("input_type"),
        "symptom_text": row.get("text_description"),
    }
    ai = {
        "triage_level": row.get("triage_level"),
        "primary_concern": row.get("primary_concern"),
        "confidence": (
            float(row["confidence_score"]) if row.get("confidence_score") is not None else None
        ),
        "tier_used": row.get("tier_used"),
        "override_applied": bool(row.get("emergency_override_applied")),
    }
    outcome_obj = {
        "user_outcome": outcome,
        "user_rating": feedback.get("rating"),
        "days_to_feedback": _years_between(row.get("created_at"), feedback.get("created_at")),
    }

    record = {
        "context": {k: v for k, v in context.items() if k in CONTEXT_ALLOWED and v is not None},
        "ai_response": {k: v for k, v in ai.items() if k in AI_ALLOWED and v is not None},
        "outcome": {k: v for k, v in outcome_obj.items() if k in OUTCOME_ALLOWED and v is not None},
        "label": _classify_signal(row.get("triage_level"), outcome),
    }
    return record


def iter_records(rows: Iterable[dict[str, Any]]):
    for row in rows:
        rec = to_training_record(row)
        if rec is not None:
            yield rec


# --- PII safety guard --------------------------------------------------------
# Belt-and-braces: any key listed here would be a contract bug — fail loudly
# rather than write a record that contains it.
PII_BLOCKLIST = {
    # ids
    "id", "analysis_id", "pet_id", "user_id", "feedback_id",
    # account / device / push / billing
    "email", "user_email", "one_signal_player_id", "revenuecat_user_id",
    # geolocation
    "lat", "lng", "latitude", "longitude", "ip", "ip_address",
    # storage references (signed but stable identifiers)
    "input_storage_key", "image_url",
}


def assert_no_pii(record: dict[str, Any]) -> None:
    """Recursively assert that no PII-coded key appears anywhere in the record.
    Raises AssertionError on the first match (the export aborts — never writes)."""
    def walk(node: Any) -> None:
        if isinstance(node, dict):
            for k, v in node.items():
                if k in PII_BLOCKLIST:
                    raise AssertionError(f"PII leak: key {k!r} present in exported record")
                walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)
    walk(record)


def dumps_jsonl(record: dict[str, Any]) -> str:
    """Serialize one training record as a single line (newline-terminated)."""
    assert_no_pii(record)
    return json.dumps(record, separators=(",", ":"), ensure_ascii=False) + "\n"
