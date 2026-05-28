"""Phase 6.2 — pure tests for the training-dataset PII-strip pipeline.

These tests use only the pure shaping function — no network, no DB, no service
role key. They are the contract test for the export pipeline; the CLI in
`scripts/export-training-dataset.py` is a thin wrapper over them.
"""
from __future__ import annotations

import pytest

from app.training_export import (
    PII_BLOCKLIST,
    assert_no_pii,
    dumps_jsonl,
    iter_records,
    to_training_record,
)


def _row(**overrides) -> dict:
    base = {
        "triage_level": "EMERGENCY",
        "primary_concern": "severe abdominal pain",
        "confidence_score": 0.87,
        "tier_used": 3,
        "emergency_override_applied": False,
        "input_type": "text",
        "text_description": "Buddy seems very lethargic and is vomiting",
        "created_at": "2026-05-20T10:00:00Z",
        "pet": {"species": "dog", "breed": "Labrador", "birth_date": "2021-06-01"},
        "analysis_feedback": [
            {"outcome": "vet_confirmed", "rating": 5, "created_at": "2026-05-23T09:00:00Z"},
        ],
        # PII fields the upstream join SHOULD never send, but if it does, the
        # PII guard must drop them on the floor.
        "id": "ANALYSIS-UUID-EVIL",
        "user_id": "USER-UUID-EVIL",
        "pet_id": "PET-UUID-EVIL",
        "input_storage_key": "r2-key-evil",
    }
    base.update(overrides)
    return base


def test_emergency_with_vet_confirmed_labels_true_positive_proxy():
    rec = to_training_record(_row())
    assert rec is not None
    assert rec["label"] == "true_positive_proxy"


def test_emergency_with_vet_said_nothing_labels_false_positive_proxy():
    rec = to_training_record(_row(analysis_feedback=[
        {"outcome": "vet_said_nothing", "rating": None, "created_at": "2026-05-23T09:00:00Z"},
    ]))
    assert rec is not None
    assert rec["label"] == "false_positive_proxy"


def test_normal_with_vet_confirmed_labels_false_negative_proxy():
    """The SAFETY-CRITICAL class — the founder reviews these to add cases to
    the Phase 6.1 golden set."""
    rec = to_training_record(_row(
        triage_level="NORMAL",
        analysis_feedback=[
            {"outcome": "vet_confirmed", "rating": 1, "created_at": "2026-05-23T09:00:00Z"},
        ],
    ))
    assert rec is not None
    assert rec["label"] == "false_negative_proxy"


def test_normal_with_resolved_on_own_labels_true_negative_proxy():
    rec = to_training_record(_row(
        triage_level="NORMAL",
        analysis_feedback=[
            {"outcome": "resolved_on_own", "rating": None, "created_at": "2026-05-23T09:00:00Z"},
        ],
    ))
    assert rec is not None
    assert rec["label"] == "true_negative_proxy"


def test_still_monitoring_outcome_has_null_label():
    rec = to_training_record(_row(
        triage_level="MONITOR",
        analysis_feedback=[
            {"outcome": "still_monitoring", "rating": 3, "created_at": "2026-05-23T09:00:00Z"},
        ],
    ))
    assert rec is not None
    assert rec["label"] is None


def test_record_carries_no_pii_keys():
    rec = to_training_record(_row())
    assert rec is not None
    # The PII guard would raise if any blocklisted key were present.
    assert_no_pii(rec)
    line = dumps_jsonl(rec)
    # And, for defense-in-depth, the serialized line should not even contain
    # any of the upstream PII strings — proving the strip happened before
    # serialization, not as a post-process.
    assert "ANALYSIS-UUID-EVIL" not in line
    assert "USER-UUID-EVIL" not in line
    assert "PET-UUID-EVIL" not in line
    assert "r2-key-evil" not in line


def test_record_contains_only_allowed_top_level_keys():
    rec = to_training_record(_row())
    assert rec is not None
    assert set(rec.keys()) == {"context", "ai_response", "outcome", "label"}


def test_record_age_years_computed_at_analysis_time():
    rec = to_training_record(_row(
        pet={"species": "dog", "breed": "Lab", "birth_date": "2020-05-20"},
        created_at="2026-05-20T10:00:00Z",
    ))
    assert rec is not None
    # 6 years to the day.
    assert rec["context"]["age_years"] == 6.0


def test_record_omitted_when_no_outcome_yet():
    """An analysis with no feedback row (or with a feedback row carrying only
    a rating, no outcome) is not training-useful — the export must skip it."""
    no_feedback = _row(analysis_feedback=[])
    rating_only = _row(analysis_feedback=[{"outcome": None, "rating": 5, "created_at": None}])
    assert to_training_record(no_feedback) is None
    assert to_training_record(rating_only) is None


def test_assert_no_pii_catches_a_planted_leak():
    leaky = {"context": {"species": "dog"}, "user_id": "OOPS"}
    with pytest.raises(AssertionError, match="PII leak"):
        assert_no_pii(leaky)


def test_dumps_jsonl_raises_on_planted_leak():
    leaky = {"context": {"species": "dog", "email": "x@y.z"}}
    with pytest.raises(AssertionError):
        dumps_jsonl(leaky)


def test_iter_records_filters_outcome_less_rows():
    rows = [_row(), _row(analysis_feedback=[]), _row()]
    out = list(iter_records(rows))
    assert len(out) == 2


def test_pii_blocklist_covers_the_canonical_set():
    """If this fails, someone shortened the blocklist; reject."""
    expected = {
        "id", "analysis_id", "pet_id", "user_id", "feedback_id",
        "email", "user_email", "one_signal_player_id", "revenuecat_user_id",
        "lat", "lng", "latitude", "longitude", "ip", "ip_address",
        "input_storage_key", "image_url",
    }
    assert expected.issubset(PII_BLOCKLIST)
