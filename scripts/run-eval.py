#!/usr/bin/env python3
"""Golden-Set regression eval runner (Phase 6.1 / CR #2-eval).

Drives `ai-service/tests/golden_set.json` through the real pipeline using stub
providers, prints a table, and **exits non-zero if any EMERGENCY case is
mis-classified**. This is the safety gate for the personalization engine:
adding history must not allow a known EMERGENCY to drop to MONITOR/NORMAL.

Usage:
  ai-service/.venv/bin/python scripts/run-eval.py
  ai-service/.venv/bin/python scripts/run-eval.py --golden-set custom.json
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Allow running from anywhere in the repo without installing the package.
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "ai-service"))

from app.eval_harness import format_report, load_golden_set, run_eval  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description="PawDoc AI golden-set eval.")
    parser.add_argument(
        "--golden-set",
        default=str(ROOT / "ai-service" / "tests" / "golden_set.json"),
        help="Path to the golden-set JSON.",
    )
    args = parser.parse_args()

    cases = load_golden_set(args.golden_set)
    report = run_eval(cases)
    print(format_report(report))

    # HARD SAFETY GATE — any false negative on an EMERGENCY case fails the build.
    if report.false_negatives_on_emergency > 0:
        print(
            f"\nSAFETY GATE FAILED: {report.false_negatives_on_emergency} EMERGENCY "
            "case(s) regressed to a non-EMERGENCY triage. Investigate immediately.",
            file=sys.stderr,
        )
        return 2

    if report.failed > 0:
        print(
            f"\n{report.failed} non-emergency case(s) failed — review before merging.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
