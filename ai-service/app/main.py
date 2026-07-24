"""PawDoc AI service.

Phase 0.3 shipped /health. Phase 1.3 adds /analyze: the safety-first triage
pipeline (emergency override, Tier 2->3 routing, cross-verification, confidence
gating, kill-switch + degraded fallback). A request-id is propagated end-to-end
for tracing (CR #23).
"""
from __future__ import annotations

import hmac
import uuid

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import StreamingResponse

from . import config
from .assistant import AssistantChatRequest, stream_assistant_reply
from .cache import make_cache
from .logging_setup import (
    configure_logging,
    get_logger,
    get_request_id,
    mask_secrets,
    set_request_id,
)
from .models import AnalyzeRequest
from .moderation import AllowAllModerator, GeminiModerator, ImageModerator
from .pipeline import AnalysisPipeline
from .providers import ClaudeProvider, GeminiProvider

configure_logging()
log = get_logger("main")

SERVICE_NAME = "pawdoc-ai"
VERSION = "3.2.0"


def _docs_kwargs(is_production: bool) -> dict:
    """GAP-E11: no interactive docs or OpenAPI schema in production — the service
    is internal (Edge Functions only). In dev/test the defaults stay on."""
    if is_production:
        return {"docs_url": None, "redoc_url": None, "openapi_url": None}
    return {}


app = FastAPI(
    title="PawDoc AI Service",
    version=VERSION,
    **_docs_kwargs(config.IS_PRODUCTION),
)


def _init_sentry() -> bool:
    """GAP-D2: error monitoring. No-op without a DSN (dev/test). PII off; the
    before_send scrubber reuses mask_secrets so secrets never reach Sentry."""
    if not config.SENTRY_DSN:
        return False
    import sentry_sdk  # lazy — only imported when a DSN is configured

    def _scrub(event: dict, _hint: object) -> dict:
        try:
            if event.get("message"):
                event["message"] = mask_secrets(str(event["message"]))
            for ex in (event.get("exception", {}) or {}).get("values", []) or []:
                if ex.get("value"):
                    ex["value"] = mask_secrets(str(ex["value"]))
        except Exception:  # noqa: BLE001 — scrubbing must never drop an event
            pass
        return event

    sentry_sdk.init(
        dsn=config.SENTRY_DSN,
        environment="prod" if config.IS_PRODUCTION else "dev",
        release=VERSION,
        send_default_pii=False,
        before_send=_scrub,
        traces_sample_rate=0.0,
    )
    log.info("Sentry initialized (environment=%s)", "prod" if config.IS_PRODUCTION else "dev")
    return True


_SENTRY_ENABLED = _init_sentry()


@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    # Honor an upstream id (Edge Function) or mint one; echo it back (CR #23).
    request_id = request.headers.get("x-request-id") or uuid.uuid4().hex
    set_request_id(request_id)
    response = await call_next(request)
    response.headers["x-request-id"] = request_id
    return response


@app.get("/health")
def health() -> dict[str, str]:
    # Intentionally OPEN: Fly's machine health checks hit this with no creds.
    return {"status": "ok", "service": SERVICE_NAME, "version": VERSION}


def require_service_auth(authorization: str | None = Header(default=None)) -> None:
    """Trust boundary (Phase A). The AI service is internal — only the Supabase
    Edge Functions may reach the analysis endpoints, presenting
    `Authorization: Bearer <AI_SERVICE_TOKEN>`. The token is compared in constant
    time (hmac.compare_digest) to avoid leaking it via timing.

    FAIL CLOSED in production: if the token is unset on a prod runtime (Fly), we
    refuse every request (503) rather than serve the pipeline unauthenticated. In
    dev/test (no token, not prod) requests are allowed so local iteration and the
    unit suite run without a token. Reads config at call time so tests can patch.
    """
    expected = config.AI_SERVICE_TOKEN
    if not expected:
        if config.IS_PRODUCTION:
            log.error(
                "AI_SERVICE_TOKEN unset on a production runtime — refusing request "
                "(fail closed). Set the secret on the Fly app and redeploy."
            )
            raise HTTPException(status_code=503, detail="service authentication not configured")
        return  # dev/test: allow unauthenticated local calls
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing bearer credentials")
    presented = authorization[len("Bearer ") :]
    if not hmac.compare_digest(presented.encode("utf-8"), expected.encode("utf-8")):
        raise HTTPException(status_code=401, detail="invalid service token")


def build_moderator() -> ImageModerator:
    """Phase C (RF-8) — content hardening. A real vision moderator is MANDATORY
    in production. Without GOOGLE_AI_API_KEY there is no NSFW gate; rather than
    silently fall back to AllowAllModerator (which would accept EVERY upload),
    FAIL CLOSED on a prod runtime. Dev/test still allow AllowAllModerator so the
    suite + local iteration run without a key. Reads config at call time so tests
    can patch."""
    if config.GOOGLE_AI_API_KEY:
        return GeminiModerator(config.GOOGLE_AI_API_KEY)
    if config.IS_PRODUCTION:
        raise RuntimeError(
            "content moderation unavailable in production (GOOGLE_AI_API_KEY unset) "
            "— refusing to serve uploads unmoderated (fail closed)."
        )
    return AllowAllModerator()


def get_pipeline() -> AnalysisPipeline:
    """Provider construction is cheap and key-free (SDKs are lazy-imported on
    call), so this is safe even when keys are absent — analysis then degrades
    gracefully rather than crashing. Overridden in tests with fakes."""
    return AnalysisPipeline(
        tier2=GeminiProvider(config.GOOGLE_AI_API_KEY),
        tier3=ClaudeProvider(config.ANTHROPIC_API_KEY),
        cache=make_cache(),
        moderator=build_moderator(),
    )


@app.post("/assistant/chat", dependencies=[Depends(require_service_auth)])
def assistant_chat(req: AssistantChatRequest) -> StreamingResponse:
    """Next Evolution Phase 4 — the conversational assistant, streamed as SSE.
    Same trust boundary as /analyze (Edge Functions only). The emergency
    keyword override runs inside the generator BEFORE any model call."""
    return StreamingResponse(
        stream_assistant_reply(req),
        media_type="text/event-stream",
        headers={
            "cache-control": "no-cache",
            "x-accel-buffering": "no",  # never buffer a live stream
        },
    )


@app.post("/analyze", dependencies=[Depends(require_service_auth)])
def analyze(req: AnalyzeRequest, pipeline: AnalysisPipeline = Depends(get_pipeline)) -> dict:
    outcome = pipeline.run(req)
    # R4 cost telemetry: one structured line per analysis — the first spend
    # visibility this codebase has ever had. Aggregate in logs; alert upstream.
    log.info(
        "analysis_telemetry action=%s tier=%d model=%s input_tokens=%s output_tokens=%s latency_ms=%d degraded=%s",
        outcome.result.action.value,
        outcome.tier_used,
        outcome.model_used,
        outcome.usage.get("input_tokens"),
        outcome.usage.get("output_tokens"),
        outcome.latency_ms,
        outcome.degraded,
    )
    return {
        "result": outcome.result.model_dump(),
        "meta": {
            "tier_used": outcome.tier_used,
            "model_used": outcome.model_used,
            "emergency_override_applied": outcome.emergency_override_applied,
            "cross_verify_scheduled": outcome.cross_verify_scheduled,
            "degraded": outcome.degraded,
            "moderation_rejected": outcome.moderation_rejected,
            "latency_ms": outcome.latency_ms,
            "usage": outcome.usage,
            "request_id": get_request_id(),
        },
    }
