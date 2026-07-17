"""AI output parser unit tests (roadmap-required: valid / invalid / malformed)."""
import pytest

from app.models import ActionLevel, AnalysisParseError, AnalysisResult, parse_analysis_result

VALID = {
    "action": "WATCH_AND_RECHECK",
    "confidence": 0.7,
    "observation": "Mild GI upset",
    "visible_symptoms": ["soft stool"],
    "recommended_actions": ["Withhold food 12h", "Offer water"],
    "urgency_timeframe": "within 24 hours",
    "disclaimer_required": True,
}


def test_parses_valid_dict():
    r = parse_analysis_result(VALID)
    assert isinstance(r, AnalysisResult)
    assert r.action is ActionLevel.WATCH_AND_RECHECK


def test_parses_valid_json_string():
    import json

    r = parse_analysis_result(json.dumps(VALID))
    assert r.confidence == 0.7


def test_malformed_json_raises():
    with pytest.raises(AnalysisParseError, match="malformed JSON"):
        parse_analysis_result('{"action": "WATCH_AND_RECHECK", ')  # truncated


def test_off_schema_raises():
    bad = dict(VALID)
    bad["action"] = "SEVERE"  # not a valid enum value
    with pytest.raises(AnalysisParseError, match="off-schema"):
        parse_analysis_result(bad)


def test_out_of_range_confidence_raises():
    bad = dict(VALID)
    bad["confidence"] = 1.7  # must be 0..1
    with pytest.raises(AnalysisParseError):
        parse_analysis_result(bad)
