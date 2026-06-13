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

from . import config
from .cache import make_cache
from .embeddings import build_embedding_input, make_embedding_provider
from .journal import JournalProvider, make_journal_provider
from .logging_setup import (
    configure_logging,
    get_logger,
    get_request_id,
    mask_secrets,
    set_request_id,
)
from .models import AnalyzeRequest, EmbedRequest, JournalRequest
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


@app.post("/analyze", dependencies=[Depends(require_service_auth)])
def analyze(req: AnalyzeRequest, pipeline: AnalysisPipeline = Depends(get_pipeline)) -> dict:
    outcome = pipeline.run(req)
    return {
        "result": outcome.result.model_dump(),
        "meta": {
            "tier_used": outcome.tier_used,
            "model_used": outcome.model_used,
            "emergency_override_applied": outcome.emergency_override_applied,
            "cross_verified": outcome.cross_verified,
            "degraded": outcome.degraded,
            "moderation_rejected": outcome.moderation_rejected,
            "latency_ms": outcome.latency_ms,
            "request_id": get_request_id(),
        },
    }


@app.post("/embed", dependencies=[Depends(require_service_auth)])
def embed(req: EmbedRequest) -> dict:
    """Semantic-cache embedding (Phase 3.2). Returns the 1536-dim vector for the
    pet-context + symptom text, or {"embedding": null} when embeddings aren't
    available (no key / disabled / error) — the Edge Function then skips the
    cache and runs a normal analysis. Best-effort; never blocks triage."""
    vector = make_embedding_provider().embed(build_embedding_input(req.pet, req.text_description))
    return {
        "embedding": vector,
        "model": config.EMBEDDING_MODEL if vector else None,
        "dim": config.EMBEDDING_DIM,
        "request_id": get_request_id(),
    }


def get_journal_provider() -> JournalProvider:
    """Resolves the journal provider; overridden in tests with a fake."""
    return make_journal_provider()


@app.post("/generate_journal", dependencies=[Depends(require_service_auth)])
def generate_journal(
    req: JournalRequest,
    provider: JournalProvider = Depends(get_journal_provider),
) -> dict:
    """AI Health Journal (Phase 5.3). Returns the synthesized narrative or
    {"narrative": null} on ANY OpenAI failure (CR #5 resilience) — the cron Edge
    Function then logs + skips that pet without writing partial data."""
    narrative = provider.generate(req)
    return {
        "narrative": narrative,
        "model": config.OPENAI_MODEL if narrative else None,
        "request_id": get_request_id(),
    }
