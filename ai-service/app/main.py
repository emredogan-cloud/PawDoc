"""PawDoc AI service — Phase 0.3 placeholder.

Exposes ``GET /health`` only. The real ``/analyze`` orchestration (emergency
override, tier routing, structured output) lands in Phase 1.3.

This sub-phase exists to prove the always-warm Fly.io deploy works with zero
cold starts — not to ship any AI logic. Keep it minimal.
"""
from __future__ import annotations

from fastapi import FastAPI

SERVICE_NAME = "pawdoc-ai"
VERSION = "0.3.0"

app = FastAPI(title="PawDoc AI Service", version=VERSION)


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness probe.

    Used by the Fly.io health check (see ``fly.toml``) and, from Phase 0.4,
    by Better Uptime. Must stay cheap and dependency-free so it reflects
    process liveness, not downstream availability.
    """
    return {"status": "ok", "service": SERVICE_NAME, "version": VERSION}
