"""Tests for app.services.parser."""

from __future__ import annotations

import json

from app.services.parser import ParseFailure, ParseSuccess, parse_provider_output


def _valid_payload() -> dict[str, object]:
    return {
        "triage_level": "MONITOR",
        "confidence": 0.72,
        "primary_concern": "Mild ear irritation, possible early otitis externa.",
        "visible_symptoms": ["head shaking", "redness inside ear"],
        "differential": ["otitis externa", "ear mites"],
        "recommended_actions": ["Avoid swimming for 48h", "Schedule a vet visit within 1 week"],
        "urgency_timeframe": "Within 1 week.",
    }


def test_parse_valid_dict() -> None:
    result = parse_provider_output(_valid_payload())
    assert isinstance(result, ParseSuccess)
    assert result.value.triage_level == "MONITOR"
    assert result.value.confidence == 0.72


def test_parse_valid_json_string() -> None:
    result = parse_provider_output(json.dumps(_valid_payload()))
    assert isinstance(result, ParseSuccess)


def test_parse_rejects_malformed_json() -> None:
    result = parse_provider_output("{not: valid json")
    assert isinstance(result, ParseFailure)
    assert result.reason.startswith("invalid_json")


def test_parse_rejects_missing_required_field() -> None:
    payload = _valid_payload()
    del payload["primary_concern"]
    result = parse_provider_output(payload)
    assert isinstance(result, ParseFailure)
    assert "primary_concern" in result.reason


def test_parse_rejects_out_of_range_confidence() -> None:
    payload = _valid_payload()
    payload["confidence"] = 1.42
    result = parse_provider_output(payload)
    assert isinstance(result, ParseFailure)
    assert "confidence" in result.reason


def test_parse_rejects_bad_triage_level() -> None:
    payload = _valid_payload()
    payload["triage_level"] = "URGENT"  # not in enum
    result = parse_provider_output(payload)
    assert isinstance(result, ParseFailure)
    assert "triage_level" in result.reason


def test_parse_rejects_empty_recommended_actions() -> None:
    payload = _valid_payload()
    payload["recommended_actions"] = []
    result = parse_provider_output(payload)
    assert isinstance(result, ParseFailure)


def test_parse_rejects_extra_field() -> None:
    """extra='forbid' on the model means unknown fields are errors."""
    payload = _valid_payload()
    payload["secret_field"] = "leaked"
    result = parse_provider_output(payload)
    assert isinstance(result, ParseFailure)


def test_parse_rejects_non_object_root() -> None:
    result = parse_provider_output('"a string"')
    assert isinstance(result, ParseFailure)
    assert "response_not_object" in result.reason
