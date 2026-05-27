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
from .logging_setup import configure_logging, get_logger, get_request_id, set_request_id
from .models import AnalyzeRequest
from .pipeline import AnalysisPipeline
from .providers import ClaudeProvider, GeminiProvider

configure_logging()
log = get_logger("main")

SERVICE_NAME = "pawdoc-ai"
VERSION = "1.3.0"

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
    return AnalysisPipeline(
        tier2=GeminiProvider(config.GOOGLE_AI_API_KEY),
        tier3=ClaudeProvider(config.ANTHROPIC_API_KEY),
        cache=make_cache(),
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
            "latency_ms": outcome.latency_ms,
            "request_id": get_request_id(),
        },
    }
