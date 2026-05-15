"""Health check endpoint.

Two roles:
1. Fly.io's HTTP service check polls ``/health`` and gates traffic on a 200.
2. Better Uptime (or any external monitor) polls the same endpoint.

Deliberately stays free of any dependency on upstream providers — a transient
Anthropic outage should NOT take the service "unhealthy" in Fly's eyes. Deep
readiness (with provider checks) lands in Phase 1 as a separate ``/ready``.
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter

from app import __version__
from app.core.config import get_settings
from app.models.schemas import HealthStatus

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthStatus, summary="Liveness probe")
async def health() -> HealthStatus:
    settings = get_settings()
    return HealthStatus(
        version=__version__,
        environment=settings.app_env.value,
        timestamp=datetime.now(UTC),
    )
