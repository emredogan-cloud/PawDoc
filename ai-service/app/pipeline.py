"""Analysis orchestration. Order matters for safety:
  1. kill-switch (CR #19) -> degraded fallback (CR #5)
  2. hardcoded emergency override, BEFORE any AI call -> GET_HELP_NOW
  3. Tier 2 (Gemini); confidence > 0.85 -> accept, else escalate to Tier 3 (Claude)
  4. cross-verify any GET_HELP_NOW asynchronously (telemetry — never delays)
  5. confidence < 0.60 -> "insufficient information" (never fabricate)
  6. ladder-floor re-check (CR #4): a risky WATCH_AND_RECHECK escalates/tightens
  7. force disclaimer_required at the API level
  A Tier-2 provider failure fails OVER to Tier 3 (resilience: keeps triage working
  on the healthy provider); degrade to the safe fallback (CR #5) only if BOTH tiers
  fail. One retry per provider call.

  Contract-v2 invariant (the company rule): NO path below returns without an
  action and a timeframe, and no fallback ever lands below WATCH_AND_RECHECK
  with an explicit re-check window.
"""
from __future__ import annotations

import threading
import time
from collections.abc import Callable
from dataclasses import dataclass, field

from . import config
from .cache import Cache, is_ai_disabled
from .logging_setup import get_logger
from .media import MediaFetchError, gather_media
from .models import (
    ActionLevel,
    AnalysisParseError,
    AnalysisResult,
    AnalyzeRequest,
    parse_analysis_result,
)
from .moderation import AllowAllModerator, ImageModerator
from .prompts import SYSTEM_PROMPT_V1, build_personalization_block, build_user_prompt
from .providers import AIProvider, ProviderError
from .safety import (
    check_emergency_override,
    emergency_override_result,
    needs_floor_recheck,
    tighten_recheck,
)

log = get_logger("pipeline")


def _daemon_thread(job: Callable[[], None]) -> None:
    threading.Thread(target=job, daemon=True).start()


@dataclass
class AnalysisOutcome:
    result: AnalysisResult
    tier_used: int  # 0 = override/degraded, 2 = Gemini, 3 = Claude
    model_used: str
    emergency_override_applied: bool
    # B6 (evolution): cross-verification is ASYNC telemetry now — it could
    # never change the outcome (GET_HELP_NOW was kept regardless), so it no
    # longer doubles latency on the most time-critical path. This flag means
    # "a background verify was scheduled", and (dis)agreement is LOGGED.
    cross_verify_scheduled: bool
    degraded: bool
    moderation_rejected: bool
    latency_ms: int
    # R4 cost telemetry: summed provider token usage for this analysis.
    usage: dict = field(default_factory=dict)


def _degraded_result() -> AnalysisResult:
    # Safe, non-reassuring fallback when we can't analyze (CR #5/#19). Lands on
    # the ladder floor WITH an explicit re-check — never a dead end.
    return AnalysisResult(
        action=ActionLevel.WATCH_AND_RECHECK,
        confidence=0.0,
        observation="We can't analyze this right now.",
        visible_symptoms=[],
        vets_look_for=[],
        watch_for=[
            "Any worsening, new signs, or your own sense that something is wrong",
        ],
        recommended_actions=[
            "If this seems urgent, contact a veterinarian or emergency clinic now.",
            "Otherwise, please try again shortly.",
        ],
        urgency_timeframe="if urgent, contact a vet now; otherwise retry soon",
        recheck_hours=1,
        disclaimer_required=True,
    )


def _insufficient_information_result(confidence: float) -> AnalysisResult:
    return AnalysisResult(
        action=ActionLevel.WATCH_AND_RECHECK,
        confidence=confidence,
        observation="Not enough information to assess confidently.",
        visible_symptoms=[],
        vets_look_for=[],
        watch_for=[
            "Symptoms getting worse or new ones appearing",
            "Your pet stops eating or drinking",
        ],
        recommended_actions=[
            "Add a clearer photo or more detail and try again.",
            "If your pet seems unwell, contact your veterinarian.",
        ],
        urgency_timeframe="re-check within 24 hours",
        recheck_hours=24,
        disclaimer_required=True,
    )


def _media_unreadable_result() -> AnalysisResult:
    # GAP-A1: the media couldn't be fetched/decoded, so the model saw no pixels.
    # We must NOT fall back to a text-only "confident" read — land on the
    # ladder floor, name the problem, keep an explicit re-check.
    return AnalysisResult(
        action=ActionLevel.WATCH_AND_RECHECK,
        confidence=0.0,
        observation="We couldn't read the photo.",
        visible_symptoms=[],
        vets_look_for=[],
        watch_for=[
            "Any worsening while you retake the photo",
        ],
        recommended_actions=[
            "Please retake a clear, well-lit photo and try again.",
            "If your pet seems unwell, contact a veterinarian.",
        ],
        urgency_timeframe="retake and try again now",
        recheck_hours=1,
        disclaimer_required=True,
    )


class AnalysisPipeline:
    def __init__(self, tier2: AIProvider, tier3: AIProvider, cache: Cache,
                 moderator: ImageModerator | None = None,
                 cross_verify_executor: Callable[[Callable[[], None]], None] | None = None) -> None:
        self.tier2 = tier2
        self.tier3 = tier3
        self.cache = cache
        self.moderator = moderator or AllowAllModerator()
        # Injectable so tests run the verify job synchronously/deterministically.
        self.cross_verify_executor = cross_verify_executor or _daemon_thread
        self._usage_total: dict = {}

    def _track_usage(self, provider: AIProvider) -> None:
        u = getattr(provider, "last_usage", None)
        if not u:
            return
        for k in ("input_tokens", "output_tokens"):
            v = u.get(k)
            if isinstance(v, int):
                self._usage_total[k] = self._usage_total.get(k, 0) + v

    def _call(self, provider: AIProvider, request: AnalyzeRequest,
              media: list[tuple[bytes, str]] | None) -> AnalysisResult:
        """One retry on failure (roadmap), then give up (caller degrades).

        Phase 6.1 — also builds the per-pet personalization block (breed/age +
        last 30d history) and passes it as a cache-able prefix; providers that
        support prompt caching (Anthropic) will reuse it on the cross-verify
        and on repeat checks for the same pet within 5 minutes. Media bytes are
        PREFETCHED once by run() — no per-attempt refetch.
        """
        user_prompt = build_user_prompt(request)
        pet_context = build_personalization_block(
            request.pet, request.recent_analyses, request.recent_events
        )
        last: Exception | None = None
        for attempt in (1, 2):
            try:
                raw = provider.analyze(
                    SYSTEM_PROMPT_V1,
                    user_prompt,
                    media,
                    pet_context_block=pet_context,
                )
                self._track_usage(provider)
                return parse_analysis_result(raw)
            except (ProviderError, AnalysisParseError) as exc:
                last = exc
                log.warning("provider %s attempt %d failed: %s", provider.name, attempt, exc)
        raise ProviderError(f"{provider.name} failed after retry: {last}")

    def _outcome(self, result, tier, model, *, override=False, cross=False, degraded=False,
                 moderation_rejected=False, start):
        # API-level guarantee: a disclaimer is always required (cannot be removed by UI).
        result = result.model_copy(update={"disclaimer_required": True})
        return AnalysisOutcome(
            result=result,
            tier_used=tier,
            model_used=model,
            emergency_override_applied=override,
            cross_verify_scheduled=cross,
            degraded=degraded,
            moderation_rejected=moderation_rejected,
            latency_ms=int((time.monotonic() - start) * 1000),
            usage=dict(self._usage_total),
        )

    def run(self, request: AnalyzeRequest) -> AnalysisOutcome:
        start = time.monotonic()
        self._usage_total = {}

        # 1. Kill-switch (CR #19).
        if is_ai_disabled(self.cache):
            log.warning("AI kill-switch active — returning degraded fallback")
            return self._outcome(_degraded_result(), 0, "kill_switch", degraded=True, start=start)

        # 2. Hardcoded emergency override — BEFORE any AI call. Species-aware
        #    (Phase 5.1) AND locale-aware (Phase 5.4 / CR #11): global keywords
        #    + the pet's species-specific set, in the user's preferred locale.
        matched = check_emergency_override(
            request.text_description, request.pet.species, request.locale
        )
        if matched:
            log.info("emergency override fired on keyword=%s", matched)
            return self._outcome(
                emergency_override_result(matched), 0, "override", override=True, start=start
            )

        # AI-03 (evolution): fetch the image EXACTLY ONCE through the guarded
        # fetcher (SSRF/size/timeout), then moderate the bytes with the TRUE
        # mime and reuse the same bytes for every model call — no second fetch,
        # no hardcoded image/jpeg, and PNG/WebP photos moderate correctly.
        media: list[tuple[bytes, str]] | None = None
        if request.image_url:
            try:
                media = gather_media(request.image_url)
            except MediaFetchError as exc:
                log.warning("media unreadable (%s) — safe degrade (never below the floor)", exc)
                return self._outcome(
                    _media_unreadable_result(), 0, "media_error", degraded=True, start=start
                )

        # CR #8 + Phase C (RF-7): moderate BEFORE any analysis; an unsafe item
        # -> refuse (the Edge Function deletes the stored R2 object on a
        # moderation reject). is_safe_bytes fails closed (errors/blocks ->
        # unsafe), so a moderation outage rejects too.
        if media and not all(self.moderator.is_safe_bytes(d, m) for d, m in media):
            log.warning("media rejected by content moderation")
            rejected = AnalysisResult(
                action=ActionLevel.WATCH_AND_RECHECK,
                confidence=0.0,
                observation="We couldn't process this media.",
                visible_symptoms=[],
                vets_look_for=[],
                watch_for=["Any worsening while you retake the photo"],
                recommended_actions=[
                    "Please retake a clear photo of your pet.",
                    "If your pet seems unwell, contact a veterinarian.",
                ],
                urgency_timeframe="retake and try again now",
                recheck_hours=1,
                disclaimer_required=True,
            )
            return self._outcome(rejected, 0, "moderation", moderation_rejected=True, start=start)

        # 3. Tier 2 (Gemini) primary. On a Tier-2 provider failure (e.g. quota /
        #    RESOURCE_EXHAUSTED, timeout, 5xx) fail OVER to Tier 3 (Claude) instead
        #    of degrading, so triage keeps working on the healthy provider; degrade
        #    only if BOTH tiers fail. A low-confidence Tier-2 read still escalates to
        #    Tier 3 as before, and if THAT escalation call fails we degrade
        #    (unchanged — a low-confidence read is never surfaced as the final answer).
        try:
            result = self._call(self.tier2, request, media)
            tier, model = 2, self.tier2.name
        except ProviderError as exc:
            log.warning("Tier 2 (%s) failed: %s — failing over to Tier 3", self.tier2.name, exc)
            try:
                result = self._call(self.tier3, request, media)
                tier, model = 3, self.tier3.name
            except ProviderError as exc2:
                log.error("pipeline degraded after both tiers failed: %s", exc2)
                return self._outcome(_degraded_result(), 0, "degraded", degraded=True, start=start)
        else:
            if result.confidence <= config.CONFIDENCE_ROUTE_THRESHOLD:
                try:
                    result = self._call(self.tier3, request, media)
                    tier, model = 3, self.tier3.name
                except ProviderError as exc:
                    log.error("pipeline degraded after Tier-3 escalation failure: %s", exc)
                    return self._outcome(_degraded_result(), 0, "degraded", degraded=True, start=start)

        # 4. B6 (evolution): cross-verify GET_HELP_NOW ASYNCHRONOUSLY. The
        #    second Tier-3 call could never change the outcome (the rung is
        #    kept regardless) — it is pure telemetry, so it must not double
        #    latency on the most time-critical path. Respond NOW; verify in
        #    the background; LOG (dis)agreement for the accuracy dashboard.
        if result.action is ActionLevel.GET_HELP_NOW:
            def _verify_job(req=request, med=media):
                try:
                    second = self._call(self.tier3, req, med)
                    if second.action is ActionLevel.GET_HELP_NOW:
                        log.info("GET_HELP_NOW cross-verify (async): agreed")
                    else:
                        log.warning(
                            "GET_HELP_NOW cross-verify (async) DISAGREED "
                            "(second=%s); outcome already returned (safe)",
                            second.action.value,
                        )
                except ProviderError as exc:
                    log.warning("GET_HELP_NOW cross-verify (async) failed: %s", exc)
            self.cross_verify_executor(_verify_job)
            return self._outcome(result, tier, model, cross=True, start=start)

        # 5. Confidence gate — never fabricate a confident answer.
        if result.confidence < config.CONFIDENCE_FLOOR:
            log.info("confidence %.2f < floor; returning insufficient-information", result.confidence)
            return self._outcome(
                _insufficient_information_result(result.confidence), tier, model, start=start
            )

        # 6. Ladder-floor re-check (CR #4 reframed): a bottom-rung read with
        #    risk signals is escalated once; if it persists, tighten the window.
        if needs_floor_recheck(result, request):
            log.info("floor read with risk signals — re-checking (tier_used=%d)", tier)
            if tier == 2:
                try:
                    result = self._call(self.tier3, request, media)
                    tier, model = 3, self.tier3.name
                except ProviderError:
                    pass  # fall through to the tighten below
            if needs_floor_recheck(result, request):
                result = tighten_recheck(
                    result, "risk signals present despite a watch-and-recheck read"
                )

        # v2 invariant backstop: the floor must always carry a re-check window.
        if result.action is ActionLevel.WATCH_AND_RECHECK and result.recheck_hours is None:
            result = result.model_copy(update={"recheck_hours": 24})

        return self._outcome(result, tier, model, start=start)
