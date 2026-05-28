"""PawDoc AI service.

Phase 0.3 shipped /health. Phase 1.3 adds /analyze: the safety-first triage
pipeline (emergency override, Tier 2->3 routing, cross-verification, confidence
gating, kill-switch + degraded fallback). A request-id is propagated end-to-end
for tracing (CR #23).
"""
from __future__ import annotations

import uuid

from fastapi import Depends, FastAPI, Request

from . import config
from .cache import make_cache
from .embeddings import build_embedding_input, make_embedding_provider
from .journal import JournalProvider, make_journal_provider
from .logging_setup import configure_logging, get_logger, get_request_id, set_request_id
from .models import AnalyzeRequest, EmbedRequest, JournalRequest
from .moderation import AllowAllModerator, GeminiModerator
from .pipeline import AnalysisPipeline
from .providers import ClaudeProvider, GeminiProvider

configure_logging()
log = get_logger("main")

SERVICE_NAME = "pawdoc-ai"
VERSION = "3.2.0"

app = FastAPI(title="PawDoc AI Service", version=VERSION)


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
    return {"status": "ok", "service": SERVICE_NAME, "version": VERSION}


def get_pipeline() -> AnalysisPipeline:
    """Provider construction is cheap and key-free (SDKs are lazy-imported on
    call), so this is safe even when keys are absent — analysis then degrades
    gracefully rather than crashing. Overridden in tests with fakes."""
    moderator = (
        GeminiModerator(config.GOOGLE_AI_API_KEY)
        if config.GOOGLE_AI_API_KEY
        else AllowAllModerator()
    )
    return AnalysisPipeline(
        tier2=GeminiProvider(config.GOOGLE_AI_API_KEY),
        tier3=ClaudeProvider(config.ANTHROPIC_API_KEY),
        cache=make_cache(),
        moderator=moderator,
    )


@app.post("/analyze")
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


@app.post("/embed")
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


@app.post("/generate_journal")
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
