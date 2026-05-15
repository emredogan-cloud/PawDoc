"""Shared response/request schemas.

Phase 0 ships only the schemas needed for the health endpoint. The
``AnalysisRequest`` / ``AnalysisResult`` schemas land in Phase 1 alongside
the orchestration logic.
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class HealthStatus(BaseModel):
    """Minimal liveness/readiness payload.

    Used by Fly.io health checks and by external monitoring. Deliberately tiny
    to keep check latency negligible.
    """

    model_config = ConfigDict(extra="forbid")

    status: Literal["ok"] = "ok"
    service: str = Field(default="pawdoc-ai")
    version: str
    environment: str
    timestamp: datetime
