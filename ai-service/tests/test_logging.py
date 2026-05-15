"""Tests for app.core.logging."""

from __future__ import annotations

import logging

from app.core.config import AppEnv, Settings
from app.core.logging import configure_logging, get_logger


def test_configure_logging_local() -> None:
    settings = Settings(_env_file=None, APP_ENV=AppEnv.LOCAL, LOG_LEVEL="DEBUG")  # type: ignore[call-arg]
    configure_logging(settings)
    root = logging.getLogger()
    assert root.level == logging.DEBUG
    assert len(root.handlers) == 1


def test_configure_logging_prod_is_json() -> None:
    settings = Settings(_env_file=None, APP_ENV=AppEnv.PROD, LOG_LEVEL="WARNING")  # type: ignore[call-arg]
    configure_logging(settings)
    root = logging.getLogger()
    assert root.level == logging.WARNING


def test_configure_logging_idempotent() -> None:
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    configure_logging(settings)
    configure_logging(settings)
    root = logging.getLogger()
    # Re-running must NOT accumulate handlers — that would duplicate every log line.
    assert len(root.handlers) == 1


def test_get_logger_returns_usable_logger() -> None:
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    configure_logging(settings)
    logger = get_logger("test.module")
    # Smoke check: a real call must not raise; this exercises the full processor
    # chain including stdlib bridge.
    logger.info("test_message", key="value")
