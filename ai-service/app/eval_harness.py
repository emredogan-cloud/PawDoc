"""Offline regression-eval harness (Phase 6.1 / CR #2-eval).

Drives the real `AnalysisPipeline` with stub providers + a Golden-Set JSON, and
returns a structured `EvalReport`. The hard safety contract is encoded in
`false_negatives_on_emergency` — any non-zero value must fail the build.

The harness is intentionally provider-free: no API keys, no network, no
non-determinism. Each test case can carry stub `tier2_response` /
`tier3_response` objects to set what the AI "would have said"; the override
path doesn't need any of that.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from . import config
from .cache import InMemoryCache
from .models import ActionLevel, AnalyzeRequest, PetContext
from .moderation import AllowAllModerator
from .pipeline import AnalysisPipeline
from .providers import ProviderError


class _StubProvider:
    """Deterministic stand-in for a live AI provider. Returns whatever response
    the test case stamped in (with sensible NORMAL+0.9 defaults so override-only
    cases don't need to specify a response)."""

    def __init__(self, name: str, tier: int, response: dict[str, Any] | None) -> None:
        self.name = name
        self.tier = tier
        self.response = response or {
            "action": "WATCH_AND_RECHECK",
            "confidence": 0.9,
            "observation": "no concerning signs described",
            "visible_symptoms": [],
            "vets_look_for": [],
            "watch_for": ["any change"],
            "recommended_actions": ["follow up if needed"],
            "urgency_timeframe": "re-check in 24h",
            "recheck_hours": 24,
            "disclaimer_required": True,
        }
        self.calls = 0

    def analyze(self, system_prompt, user_prompt, image_url=None,
                pet_context_block=None) -> dict[str, Any]:
        self.calls += 1
        return dict(self.response)


class _FailingProvider(_StubProvider):
    """Used by the harness for tests that need the degraded path."""

    def analyze(self, *args, **kwargs):  # noqa: ANN002, ANN003
        self.calls += 1
        raise ProviderError(f"{self.name}: forced failure")


class _StubModerator:
    def __init__(self, safe: bool) -> None:
        self.safe = safe

    def is_safe(self, image_url: str) -> bool:  # noqa: ARG002
        return self.safe


def _hydrate_response(stub: dict[str, Any] | None) -> dict[str, Any] | None:
    """Fill in the AnalysisResult fields that test JSONs may omit (so a case
    only has to specify what matters — triage level + confidence + concern)."""
    if not stub:
        return None
    return {
        "action": stub.get("action", "WATCH_AND_RECHECK"),
        "confidence": stub.get("confidence", 0.9),
        "observation": stub.get("observation", "stub"),
        "visible_symptoms": stub.get("visible_symptoms", []),
        "vets_look_for": stub.get("vets_look_for", []),
        "watch_for": stub.get("watch_for", []),
        "recommended_actions": stub.get("recommended_actions", ["follow up if needed"]),
        "urgency_timeframe": stub.get("urgency_timeframe", "re-check in 24h"),
        "recheck_hours": stub.get("recheck_hours", 24),
        "disclaimer_required": True,
    }


@dataclass
class CaseResult:
    case_id: str
    category: str
    expected: str
    actual: str
    passed: bool
    notes: str = ""


@dataclass
class EvalReport:
    cases: list[CaseResult] = field(default_factory=list)

    @property
    def total(self) -> int:
        return len(self.cases)

    @property
    def passed(self) -> int:
        return sum(1 for c in self.cases if c.passed)

    @property
    def failed(self) -> int:
        return self.total - self.passed

    @property
    def false_negatives_on_emergency(self) -> int:
        """An EMERGENCY-category case where the pipeline did NOT return
        GET_HELP_NOW. This is the strict safety contract: must be zero."""
        return sum(
            1
            for c in self.cases
            if c.category == "EMERGENCY" and c.actual != "GET_HELP_NOW"
        )


def load_golden_set(path: str | Path | None = None) -> list[dict[str, Any]]:
    p = Path(path) if path else (
        Path(__file__).resolve().parent.parent / "tests" / "golden_set.json"
    )
    data = json.loads(p.read_text(encoding="utf-8"))
    return list(data.get("cases", []))


def _build_request(payload: dict[str, Any]) -> AnalyzeRequest:
    pet_payload = dict(payload.get("pet") or {"species": "dog"})
    pet = PetContext(**pet_payload)
    return AnalyzeRequest(
        input_type=payload.get("input_type", "text"),
        text_description=payload.get("text_description"),
        image_url=payload.get("image_url"),
        pet=pet,
        low_input_quality=payload.get("low_input_quality", False),
        locale=payload.get("locale", "en"),
        recent_analyses=payload.get("recent_analyses", []),
        recent_events=payload.get("recent_events", []),
    )


def _build_pipeline_for_case(case: dict[str, Any]) -> AnalysisPipeline:
    if case.get("provider_failure"):
        tier2: Any = _FailingProvider("gemini", 2, None)
        tier3: Any = _FailingProvider("claude", 3, None)
    else:
        tier2 = _StubProvider("gemini", 2, _hydrate_response(case.get("tier2_response")))
        tier3 = _StubProvider("claude", 3, _hydrate_response(case.get("tier3_response")))

    cache = InMemoryCache()
    if case.get("kill_switch"):
        cache.set(config.KILL_SWITCH_CACHE_KEY, "1")

    moderator: Any = (
        _StubModerator(safe=False)
        if case.get("moderation_safe") is False
        else AllowAllModerator()
    )
    return AnalysisPipeline(tier2=tier2, tier3=tier3, cache=cache, moderator=moderator)


def _evaluate_case(case: dict[str, Any]) -> CaseResult:
    case_id = case["id"]
    category = case["category"]
    expected = case["expected_action"]
    pipeline = _build_pipeline_for_case(case)
    outcome = pipeline.run(_build_request(case["request"]))
    actual_level: ActionLevel = outcome.result.action
    actual = actual_level.value

    notes: list[str] = []
    passed = actual == expected

    # Extra structural assertions when the case names them.
    if "expected_override" in case:
        if outcome.emergency_override_applied != case["expected_override"]:
            passed = False
            notes.append(
                f"override={outcome.emergency_override_applied} expected {case['expected_override']}"
            )
    if "expected_cross_verified" in case:
        if outcome.cross_verified != case["expected_cross_verified"]:
            passed = False
            notes.append(
                f"cross_verified={outcome.cross_verified} expected {case['expected_cross_verified']}"
            )
    if case.get("expected_degraded") and not outcome.degraded:
        passed = False
        notes.append("degraded=False expected True")
    if case.get("expected_moderation_rejected") and not outcome.moderation_rejected:
        passed = False
        notes.append("moderation_rejected=False expected True")
    expected_obs = case.get("expected_observation_contains")
    if expected_obs and expected_obs not in outcome.result.observation:
        passed = False
        notes.append(
            f"observation={outcome.result.observation!r} missing {expected_obs!r}"
        )

    return CaseResult(
        case_id=case_id,
        category=category,
        expected=expected,
        actual=actual,
        passed=passed,
        notes="; ".join(notes),
    )


def run_eval(cases: list[dict[str, Any]] | None = None) -> EvalReport:
    """Run the golden set; returns an EvalReport. Caller decides whether to
    treat `false_negatives_on_emergency > 0` as a hard failure."""
    report = EvalReport()
    for case in cases or load_golden_set():
        try:
            report.cases.append(_evaluate_case(case))
        except Exception as exc:  # noqa: BLE001 — surface as a failing case, never crash the run
            report.cases.append(
                CaseResult(
                    case_id=case.get("id", "?"),
                    category=case.get("category", "?"),
                    expected=case.get("expected_action", "?"),
                    actual="ERROR",
                    passed=False,
                    notes=f"{type(exc).__name__}: {exc}",
                )
            )
    return report


def format_report(report: EvalReport) -> str:
    """Compact human-readable table — drops into CI logs and the report."""
    width_id = max((len(c.case_id) for c in report.cases), default=2) + 2
    out: list[str] = []
    head = f"{'#':<3}{'CASE':<{width_id}}{'CAT':<11}{'EXPECT':<10}{'ACTUAL':<10}RESULT"
    out.append(head)
    out.append("-" * len(head))
    for i, c in enumerate(report.cases, 1):
        mark = "PASS" if c.passed else "FAIL"
        line = (
            f"{i:<3}{c.case_id:<{width_id}}{c.category:<11}"
            f"{c.expected:<10}{c.actual:<10}{mark}"
        )
        if c.notes:
            line += f"  ({c.notes})"
        out.append(line)
    out.append("-" * len(head))
    out.append(
        f"total={report.total}  passed={report.passed}  failed={report.failed}  "
        f"FN-on-EMERGENCY={report.false_negatives_on_emergency}"
    )
    return "\n".join(out)
