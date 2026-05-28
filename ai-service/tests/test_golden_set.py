"""Golden-Set regression eval, surfaced as a pytest case (Phase 6.1 / CR #2-eval).

Running `pytest` is now sufficient to enforce the strict safety contract:
adding personalized history to the prompt cannot regress a known EMERGENCY.
"""
from app.eval_harness import format_report, load_golden_set, run_eval


def test_golden_set_no_emergency_false_negatives():
    cases = load_golden_set()
    report = run_eval(cases)
    # Print the table on failure so CI logs show exactly which case regressed.
    assert report.false_negatives_on_emergency == 0, (
        f"\nSAFETY GATE FAILED — {report.false_negatives_on_emergency} EMERGENCY "
        "case(s) regressed.\n" + format_report(report)
    )


def test_golden_set_all_cases_pass():
    cases = load_golden_set()
    report = run_eval(cases)
    assert report.failed == 0, "\n" + format_report(report)


def test_golden_set_has_minimum_emergency_coverage():
    """The eval is meaningless if it has 0 EMERGENCY cases; this is a guard
    against accidentally deleting the safety-critical cases from the JSON."""
    cases = load_golden_set()
    emergency_cases = [c for c in cases if c["category"] == "EMERGENCY"]
    assert len(emergency_cases) >= 5, (
        f"Golden set has only {len(emergency_cases)} EMERGENCY cases — must keep "
        "at least 5 (EN keyword, DE keyword, species-specific EN, species-specific DE, "
        "AI-detected/cross-verified) for meaningful safety coverage."
    )
