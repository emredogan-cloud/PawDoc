"""Analysis orchestration. Order matters for safety:
  1. kill-switch (CR #19) -> degraded fallback (CR #5)
  2. hardcoded emergency override, BEFORE any AI call
  3. Tier 2 (Gemini); confidence > 0.85 -> accept, else escalate to Tier 3 (Claude)
  4. cross-verify any EMERGENCY with a second Tier-3 call
  5. confidence < 0.60 -> "insufficient information" (never fabricate)
  6. borderline-NORMAL re-check (CR #4): escalate / bias to MONITOR
  7. force disclaimer_required at the API level
  Provider/parse failures -> degraded fallback (CR #5). One retry on failure.
"""
from __future__ import annotations

import time
from dataclasses import dataclass

from . import config
from .cache import Cache, is_ai_disabled
from .logging_setup import get_logger
from .models import (
    AnalysisParseError,
    AnalysisResult,
    AnalyzeRequest,
    TriageLevel,
    parse_analysis_result,
)
from .prompts import SYSTEM_PROMPT_V1, build_user_prompt
from .providers import AIProvider, ProviderError
from .safety import (
    bias_to_monitor,
    check_emergency_override,
    emergency_override_result,
    needs_normal_recheck,
)

log = get_logger("pipeline")


@dataclass
class AnalysisOutcome:
    result: AnalysisResult
    tier_used: int  # 0 = override/degraded, 2 = Gemini, 3 = Claude
    model_used: str
    emergency_override_applied: bool
    cross_verified: bool
    degraded: bool
    latency_ms: int


def _degraded_result() -> AnalysisResult:
    # Safe, non-reassuring fallback (never NORMAL) when we can't analyze (CR #5/#19).
    return AnalysisResult(
        triage_level=TriageLevel.MONITOR,
        confidence=0.0,
        primary_concern="We can't analyze this right now.",
        visible_symptoms=[],
        differential=[],
        recommended_actions=[
            "If this seems urgent, contact a veterinarian or emergency clinic now.",
            "Otherwise, please try again shortly.",
        ],
        urgency_timeframe="if urgent, contact a vet now",
        disclaimer_required=True,
    )


def _insufficient_information_result(confidence: float) -> AnalysisResult:
    return AnalysisResult(
        triage_level=TriageLevel.MONITOR,
        confidence=confidence,
        primary_concern="Not enough information to assess confidently.",
        visible_symptoms=[],
        differential=[],
        recommended_actions=[
            "Add a clearer photo/video or more detail and try again.",
            "If your pet seems unwell, contact your veterinarian.",
        ],
        urgency_timeframe="seek advice if you are concerned",
        disclaimer_required=True,
    )


class AnalysisPipeline:
    def __init__(self, tier2: AIProvider, tier3: AIProvider, cache: Cache) -> None:
        self.tier2 = tier2
        self.tier3 = tier3
        self.cache = cache

    def _call(self, provider: AIProvider, request: AnalyzeRequest) -> AnalysisResult:
        """One retry on failure (roadmap), then give up (caller degrades)."""
        user_prompt = build_user_prompt(request)
        last: Exception | None = None
        for attempt in (1, 2):
            try:
                raw = provider.analyze(SYSTEM_PROMPT_V1, user_prompt, request.image_url)
                return parse_analysis_result(raw)
            except (ProviderError, AnalysisParseError) as exc:
                last = exc
                log.warning("provider %s attempt %d failed: %s", provider.name, attempt, exc)
        raise ProviderError(f"{provider.name} failed after retry: {last}")

    def _outcome(self, result, tier, model, *, override=False, cross=False, degraded=False, start):
        # API-level guarantee: a disclaimer is always required (cannot be removed by UI).
        result = result.model_copy(update={"disclaimer_required": True})
        return AnalysisOutcome(
            result=result,
            tier_used=tier,
            model_used=model,
            emergency_override_applied=override,
            cross_verified=cross,
            degraded=degraded,
            latency_ms=int((time.monotonic() - start) * 1000),
        )

    def run(self, request: AnalyzeRequest) -> AnalysisOutcome:
        start = time.monotonic()

        # 1. Kill-switch (CR #19).
        if is_ai_disabled(self.cache):
            log.warning("AI kill-switch active — returning degraded fallback")
            return self._outcome(_degraded_result(), 0, "kill_switch", degraded=True, start=start)

        # 2. Hardcoded emergency override — BEFORE any AI call.
        matched = check_emergency_override(request.text_description)
        if matched:
            log.info("emergency override fired on keyword=%s", matched)
            return self._outcome(
                emergency_override_result(matched), 0, "override", override=True, start=start
            )

        # 3. Tier 2 -> route on confidence; else Tier 3.
        try:
            result = self._call(self.tier2, request)
            tier, model = 2, self.tier2.name
            if result.confidence <= config.CONFIDENCE_ROUTE_THRESHOLD:
                result = self._call(self.tier3, request)
                tier, model = 3, self.tier3.name
        except ProviderError as exc:
            log.error("pipeline degraded after provider failure: %s", exc)
            return self._outcome(_degraded_result(), 0, "degraded", degraded=True, start=start)

        # 4. Cross-verify any EMERGENCY with a second Tier-3 call. EMERGENCY is
        #    kept regardless (safe); we record whether the second call agreed.
        cross_verified = False
        if result.triage_level is TriageLevel.EMERGENCY:
            try:
                second = self._call(self.tier3, request)
                cross_verified = second.triage_level is TriageLevel.EMERGENCY
                tier, model = 3, self.tier3.name
                if not cross_verified:
                    log.warning("EMERGENCY cross-verify disagreed; keeping EMERGENCY (safe)")
            except ProviderError:
                log.warning("EMERGENCY cross-verify call failed; keeping EMERGENCY")
            return self._outcome(result, tier, model, cross=cross_verified, start=start)

        # 5. Confidence gate — never fabricate a confident answer.
        if result.confidence < config.CONFIDENCE_FLOOR:
            log.info("confidence %.2f < floor; returning insufficient-information", result.confidence)
            return self._outcome(
                _insufficient_information_result(result.confidence), tier, model, start=start
            )

        # 6. Borderline-NORMAL re-check (CR #4).
        if needs_normal_recheck(result, request):
            log.info("borderline NORMAL with risk signals — re-checking (tier_used=%d)", tier)
            if tier == 2:
                try:
                    result = self._call(self.tier3, request)
                    tier, model = 3, self.tier3.name
                except ProviderError:
                    pass  # fall through to the MONITOR bias below
            if result.triage_level is TriageLevel.NORMAL and needs_normal_recheck(result, request):
                result = bias_to_monitor(
                    result, "risk signals present despite a NORMAL read"
                )

        return self._outcome(result, tier, model, start=start)
