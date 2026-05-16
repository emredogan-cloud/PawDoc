"""AI orchestration — the routing brain.

Flow (see ``docs/reports/phase1b-ai-plan.md`` §2-§3 for the diagram):

1. Run safety.check_emergency_override on the user's text. On match, return
   an EMERGENCY result directly — no AI calls, no quota concerns.
2. Call Gemini Flash (Tier 2). Parse + validate.
3. If the result is high-confidence and NOT EMERGENCY, return it.
4. Otherwise call Claude Sonnet (Tier 3). Parse + validate.
5. If Tier 3 reports EMERGENCY, call Claude Sonnet again to cross-verify.
   - Both EMERGENCY → confirmed EMERGENCY.
   - Disagree → downgrade to MONITOR with `cross_verify_disagreement = True`.
6. Apply the confidence floor: if confidence < 0.60, override to MONITOR
   with a graceful "insufficient information" payload.

On unrecoverable provider errors, return a graceful-degradation result
rather than raising. The caller (the edge function) gets a usable
``AnalysisResult`` for every legal request — never an internal-error
response.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Protocol

from app.core.config import Settings
from app.core.exceptions import UpstreamError
from app.core.logging import get_logger
from app.core.observability import Timer
from app.models.schemas import (
    AnalysisProviderOutput,
    AnalysisRequest,
    AnalysisResult,
)
from app.prompts.breed_context import breed_context_for
from app.prompts.system_prompt import PARSER_RETRY_HINT, SYSTEM_PROMPT
from app.services.copy import (
    DEGRADATION_PRIMARY_CONCERN,
    DEGRADATION_URGENCY,
    EMERGENCY_URGENCY,
    degradation_recommended_actions,
)
from app.services.gemini_client import build_user_prompt
from app.services.parser import ParseSuccess, parse_provider_output
from app.services.safety import (
    EmergencyMatch,
    check_emergency_override,
    emergency_recommended_actions,
    emergency_response_text,
)

log = get_logger(__name__)


class GeminiPort(Protocol):
    """Structural interface for the Tier-2 provider client.

    Defined here so tests can inject fakes without depending on httpx.
    The production implementation is ``GeminiClient``.
    """

    async def analyze(self, system_prompt: str, user_prompt: str) -> str: ...


class ClaudePort(Protocol):
    """Structural interface for the Tier-3 provider client."""

    async def analyze(self, system_prompt: str, user_prompt: str) -> dict[str, Any]: ...


@dataclass(slots=True)
class Orchestrator:
    settings: Settings
    gemini: GeminiPort
    claude: ClaudePort

    async def analyze(self, request: AnalysisRequest) -> AnalysisResult:
        with Timer("orchestrator_total", log) as total:
            result = await self._analyze_inner(request)
        # Patch the latency in the immutable model — we recreate the
        # object rather than mutate.
        return result.model_copy(update={"ai_latency_ms": total.elapsed_ms})

    # ---- Internal flow -----------------------------------------------------

    async def _analyze_inner(self, request: AnalysisRequest) -> AnalysisResult:
        # 1. Safety: emergency keyword override.
        override = check_emergency_override(request.text_description)
        if override.matched:
            log.info("emergency_override_triggered", keyword=override.keyword)
            return _emergency_override_result(request, override)

        breed_ctx = breed_context_for(request.pet.species, request.pet.breed)
        user_prompt = build_user_prompt(request, breed_ctx)

        # 2-3. Tier 2 — Gemini Flash.
        try:
            tier2 = await self._run_gemini(user_prompt)
        except _ProviderFailure as e:
            log.warning("tier2_failed_escalating_to_tier3", reason=e.reason)
            tier2 = None

        if (
            tier2 is not None
            and tier2.confidence >= self.settings.tier2_confidence_floor
            and tier2.triage_level != "EMERGENCY"
        ):
            log.info("tier2_resolved", confidence=tier2.confidence)
            return _wrap(
                tier2,
                request=request,
                model_used=self.settings.gemini_model,
                tier_used=2,
            )

        # 4. Tier 3 — Claude Sonnet.
        try:
            tier3 = await self._run_claude(user_prompt)
        except _ProviderFailure as e:
            log.error("tier3_failed_graceful", reason=e.reason)
            return _graceful_degradation(request)

        if tier3.confidence < self.settings.insufficient_confidence_floor:
            log.warning("tier3_below_confidence_floor", confidence=tier3.confidence)
            return _graceful_degradation(request)

        # 5. Cross-verify EMERGENCY classifications.
        if tier3.triage_level == "EMERGENCY":
            try:
                verify = await self._run_claude(user_prompt)
            except _ProviderFailure as e:
                log.warning(
                    "cross_verify_failed_keeping_emergency",
                    reason=e.reason,
                )
                return _wrap(
                    tier3,
                    request=request,
                    model_used=self.settings.claude_model,
                    tier_used=3,
                    cross_verify_disagreement=False,
                )
            if verify.triage_level == "EMERGENCY":
                log.info("cross_verify_confirmed_emergency")
                return _wrap(
                    tier3,
                    request=request,
                    model_used=self.settings.claude_model,
                    tier_used=3,
                )
            log.warning(
                "cross_verify_disagreement",
                first=tier3.triage_level,
                second=verify.triage_level,
            )
            # Downgrade to MONITOR but keep the urgency_timeframe and
            # actions so the user is still told to act soon.
            downgraded = tier3.model_copy(
                update={
                    "triage_level": "MONITOR",
                    "confidence": min(tier3.confidence, verify.confidence),
                }
            )
            return _wrap(
                downgraded,
                request=request,
                model_used=self.settings.claude_model,
                tier_used=3,
                cross_verify_disagreement=True,
            )

        return _wrap(
            tier3,
            request=request,
            model_used=self.settings.claude_model,
            tier_used=3,
        )

    # ---- Provider calls (with parser-retry handling) -----------------------

    async def _run_gemini(self, user_prompt: str) -> AnalysisProviderOutput:
        try:
            raw = await self.gemini.analyze(SYSTEM_PROMPT, user_prompt)
        except UpstreamError as e:
            raise _ProviderFailure(f"gemini_upstream: {e.message}") from e
        parsed = parse_provider_output(raw)
        if isinstance(parsed, ParseSuccess):
            return parsed.value
        # One retry with a stricter reminder appended to the user message.
        log.warning("gemini_parser_retry", reason=parsed.reason)
        try:
            retry_raw = await self.gemini.analyze(SYSTEM_PROMPT, user_prompt + PARSER_RETRY_HINT)
        except UpstreamError as e:
            raise _ProviderFailure(f"gemini_upstream: {e.message}") from e
        retry = parse_provider_output(retry_raw)
        if isinstance(retry, ParseSuccess):
            return retry.value
        raise _ProviderFailure(f"gemini_parse: {retry.reason}")

    async def _run_claude(self, user_prompt: str) -> AnalysisProviderOutput:
        try:
            tool_input = await self.claude.analyze(SYSTEM_PROMPT, user_prompt)
        except UpstreamError as e:
            raise _ProviderFailure(f"claude_upstream: {e.message}") from e
        parsed = parse_provider_output(tool_input)
        if isinstance(parsed, ParseSuccess):
            return parsed.value
        log.warning("claude_parser_retry", reason=parsed.reason)
        try:
            retry_input = await self.claude.analyze(
                SYSTEM_PROMPT,
                user_prompt + PARSER_RETRY_HINT,
            )
        except UpstreamError as e:
            raise _ProviderFailure(f"claude_upstream: {e.message}") from e
        retry = parse_provider_output(retry_input)
        if isinstance(retry, ParseSuccess):
            return retry.value
        raise _ProviderFailure(f"claude_parse: {retry.reason}")


# ---------------------------------------------------------------------------
# Helpers + internal types
# ---------------------------------------------------------------------------


class _ProviderFailure(Exception):
    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


def _emergency_override_result(
    request: AnalysisRequest,
    override: EmergencyMatch,
) -> AnalysisResult:
    return AnalysisResult(
        triage_level="EMERGENCY",
        confidence=1.0,
        primary_concern=emergency_response_text(override.keyword),
        visible_symptoms=[],
        differential=[],
        recommended_actions=emergency_recommended_actions(),
        urgency_timeframe=EMERGENCY_URGENCY,
        model_used="emergency_override",
        tier_used=1,
        emergency_override_applied=True,
        ai_latency_ms=0,
        request_id=request.request_id,
    )


def _graceful_degradation(request: AnalysisRequest) -> AnalysisResult:
    return AnalysisResult(
        triage_level="MONITOR",
        confidence=0.0,
        primary_concern=DEGRADATION_PRIMARY_CONCERN,
        visible_symptoms=[],
        differential=[],
        recommended_actions=degradation_recommended_actions(),
        urgency_timeframe=DEGRADATION_URGENCY,
        model_used="graceful_degradation",
        tier_used=0,
        ai_latency_ms=0,
        request_id=request.request_id,
    )


def _wrap(
    output: AnalysisProviderOutput,
    *,
    request: AnalysisRequest,
    model_used: str,
    tier_used: int,
    cross_verify_disagreement: bool = False,
) -> AnalysisResult:
    return AnalysisResult(
        triage_level=output.triage_level,
        confidence=output.confidence,
        primary_concern=output.primary_concern,
        visible_symptoms=output.visible_symptoms,
        differential=output.differential,
        recommended_actions=output.recommended_actions,
        urgency_timeframe=output.urgency_timeframe,
        model_used=model_used,
        tier_used=tier_used,  # type: ignore[arg-type]
        cross_verify_disagreement=cross_verify_disagreement,
        ai_latency_ms=0,  # patched by Orchestrator.analyze
        request_id=request.request_id,
    )
