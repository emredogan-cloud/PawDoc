"""Structured JSON logging configured for production use.

Decisions:
- JSON output in dev/prod so log aggregators (Sentry breadcrumbs, Fly logs,
  any future log shipper) get parseable records.
- Human-readable console output in local.
- Standard ``logging`` module is wrapped so any third-party logs get the same
  formatter — important because FastAPI, uvicorn, and httpx all log through
  stdlib logging.
- Secrets must NEVER appear in logs. ``SecretStr`` values from Pydantic are
  safe to log (they render as ``**********``); raw strings passed by callers
  are the caller's responsibility — this module does not introspect message
  payloads.
"""

from __future__ import annotations

import logging
import sys
from typing import Any

import structlog
from structlog.types import EventDict, Processor

from app.core.config import AppEnv, Settings


def _drop_color_message_key(_: Any, __: Any, event_dict: EventDict) -> EventDict:
    """Uvicorn injects a ``color_message`` key — drop it from JSON output."""
    event_dict.pop("color_message", None)
    return event_dict


def configure_logging(settings: Settings) -> None:
    """Wire ``logging`` and ``structlog`` together with a single processor chain.

    Call this exactly once at process startup. Safe to call again (idempotent).
    """
    timestamper = structlog.processors.TimeStamper(fmt="iso", utc=True)

    shared_processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.StackInfoRenderer(),
        _drop_color_message_key,
        timestamper,
    ]

    if settings.app_env is AppEnv.LOCAL:
        renderer: Processor = structlog.dev.ConsoleRenderer(colors=sys.stdout.isatty())
    else:
        shared_processors.append(structlog.processors.format_exc_info)
        renderer = structlog.processors.JSONRenderer()

    # structlog → stdlib bridge.
    structlog.configure(
        processors=[
            *shared_processors,
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        structlog.stdlib.ProcessorFormatter(
            foreign_pre_chain=shared_processors,
            processors=[
                structlog.stdlib.ProcessorFormatter.remove_processors_meta,
                renderer,
            ],
        )
    )

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    root_logger.setLevel(settings.log_level)

    # Quiet the noisy access logger; uvicorn re-emits requests through ours.
    logging.getLogger("uvicorn.access").handlers.clear()
    logging.getLogger("uvicorn.access").propagate = False


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """Return a typed structlog logger for a module."""
    return structlog.stdlib.get_logger(name)
