"""FastAPI application entrypoint.

This module is the thin composition root: it builds the app instance, wires
middleware, registers routers and exception handlers, and configures logging.
Business logic lives in ``app/services`` and ``app/routers``; nothing here
should grow beyond plumbing.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import __version__
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging, get_logger
from app.routers import analyze, health


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    """Process-wide startup/shutdown hooks."""
    settings = get_settings()
    configure_logging(settings)
    log = get_logger("app.main")
    log.info(
        "service_starting",
        version=__version__,
        environment=settings.app_env.value,
        port=settings.port,
    )
    yield
    log.info("service_shutdown")


def create_app() -> FastAPI:
    """Application factory.

    Returning the app from a function rather than instantiating at module
    scope makes the app trivially testable and lets us spin up isolated
    instances per test without import side effects.
    """
    settings = get_settings()

    app = FastAPI(
        title="PawDoc AI Service",
        version=__version__,
        description="AI orchestration for pet-health triage.",
        # Hide docs in prod — internal tool, not a public API.
        docs_url=None if settings.is_production else "/docs",
        redoc_url=None,
        openapi_url=None if settings.is_production else "/openapi.json",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins(),
        allow_credentials=True,
        allow_methods=["GET", "POST"],
        allow_headers=["Authorization", "Content-Type"],
        max_age=600,
    )

    register_exception_handlers(app)
    app.include_router(health.router)
    app.include_router(analyze.router)

    return app


app = create_app()
