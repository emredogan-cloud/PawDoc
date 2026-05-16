"""Health + readiness endpoints.

Two distinct probes, by design:

- ``/health`` — **liveness**. Fly.io's HTTP service check polls this.
  Returns 200 as long as the process is up. NEVER touches upstream
  providers; a transient Anthropic outage must not make Fly cycle the
  machine.

- ``/ready`` — **readiness** (Sprint B3 / F-OPS3). Returns 200 only
  when this process has the configuration it needs to serve real
  traffic, 503 otherwise. Better Uptime and any synthetic monitor
  should poll this endpoint. Like ``/health``, it makes no outbound
  calls — readiness is config-level, not provider-level. Provider
  health is observed via per-request orchestrator metrics.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Literal

from fastapi import APIRouter, Response

from app import __version__
from app.core.config import AppEnv, get_settings
from app.models.schemas import HealthStatus
from pydantic import BaseModel, ConfigDict

router = APIRouter(tags=["health"])


class ReadinessStatus(BaseModel):
    """Shape returned by the readiness probe.

    `status` is the headline signal Better Uptime / cURL-based scripts
    consume; `missing` lists the env vars the operator still owes the
    process. Both 200 and 503 responses use this shape so monitors can
    parse a single schema.
    """

    model_config = ConfigDict(extra="forbid")

    status: Literal["ready", "degraded"]
    service: str = "pawdoc-ai"
    version: str
    environment: str
    timestamp: datetime
    missing: list[str] = []


@router.get("/health", response_model=HealthStatus, summary="Liveness probe")
async def health() -> HealthStatus:
    settings = get_settings()
    return HealthStatus(
        version=__version__,
        environment=settings.app_env.value,
        timestamp=datetime.now(UTC),
    )


def _missing_required(settings: object) -> list[str]:
    """Compute the list of unset env vars that block readiness.

    Mirrors `Settings._validate_prod_keys` but does NOT raise — readiness
    must report degraded state without crashing the process. The function
    works against the live `Settings` instance so a future addition only
    has to update both lists in one PR review.
    """
    # Local imports avoid a circular dep at module load.
    from app.core.config import Settings

    s: Settings = settings  # type: ignore[assignment]
    missing: list[str] = []
    if s.internal_api_token is None:
        missing.append("INTERNAL_API_TOKEN")
    if s.anthropic_api_key is None:
        missing.append("ANTHROPIC_API_KEY")
    if s.google_ai_api_key is None:
        missing.append("GOOGLE_AI_API_KEY")
    if s.supabase_url is None:
        missing.append("SUPABASE_URL")
    if s.supabase_service_role_key is None:
        missing.append("SUPABASE_SERVICE_ROLE_KEY")
    return missing


@router.get(
    "/ready",
    response_model=ReadinessStatus,
    summary="Readiness probe (config-level)",
    responses={
        200: {"description": "All required secrets configured."},
        503: {"description": "One or more required secrets unset."},
    },
)
async def ready(response: Response) -> ReadinessStatus:
    settings = get_settings()
    missing = _missing_required(settings)

    # LOCAL is explicitly lenient — a developer running `uv run uvicorn`
    # without secrets should still see `ready` (200) so they can poll
    # the endpoint while wiring up their .env. PROD/DEV require the
    # config to be complete.
    is_ready = not missing or settings.app_env is AppEnv.LOCAL
    if not is_ready:
        response.status_code = 503
    return ReadinessStatus(
        status="ready" if is_ready else "degraded",
        version=__version__,
        environment=settings.app_env.value,
        timestamp=datetime.now(UTC),
        missing=missing,
    )
