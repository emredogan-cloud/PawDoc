"""Tests for app.core.sentry."""

from __future__ import annotations

from typing import Any

import app.core.sentry as sentry_module
from app.core.config import AppEnv, Settings


def _settings(dsn: str | None = None, env: AppEnv = AppEnv.LOCAL) -> Settings:
    kwargs: dict[str, Any] = {"_env_file": None, "APP_ENV": env.value}
    if dsn is not None:
        kwargs["SENTRY_DSN"] = dsn
    return Settings(**kwargs)  # type: ignore[arg-type]


def setup_function(_: Any) -> None:
    # Reset the module's idempotency latch so tests are independent.
    sentry_module._initialized = False


def test_init_sentry_noop_when_dsn_missing() -> None:
    """Without a DSN the SDK must NOT raise (local dev convenience)."""
    initialised = sentry_module.init_sentry(_settings(dsn=None))
    assert initialised is False
    assert sentry_module._initialized is False


def test_init_sentry_idempotent() -> None:
    """Calling twice should not double-init."""
    sentry_module._initialized = True  # pretend we've already run
    assert sentry_module.init_sentry(_settings(dsn="https://x@sentry.io/1")) is True


def test_scrub_event_removes_request_body() -> None:
    event = {
        "request": {
            "data": {"secret_pet_description": "private"},
            "query_string": "token=abcdef",
            "headers": {
                "authorization": "Bearer ey...",
                "user-agent": "PawDoc/0.1",
                "x-request-id": "req_test",
            },
        }
    }
    scrubbed = sentry_module._scrub_event(event, {})
    assert scrubbed is not None
    req = scrubbed["request"]
    assert "data" not in req
    assert "query_string" not in req
    assert "authorization" not in req["headers"]
    # User-agent + request id are kept for diagnostic value.
    assert req["headers"]["user-agent"] == "PawDoc/0.1"
    assert req["headers"]["x-request-id"] == "req_test"


def test_scrub_event_drops_email_and_other_pii() -> None:
    event = {
        "user": {
            "id": "uuid-1",
            "email": "private@example.com",
            "username": "private",
            "ip_address": "1.2.3.4",
        }
    }
    scrubbed = sentry_module._scrub_event(event, {})
    assert scrubbed is not None
    assert scrubbed["user"] == {"id": "uuid-1"}


def test_scrub_event_handles_missing_request() -> None:
    """No 'request' key on the event should not blow up."""
    event = {"level": "error", "message": "boom"}
    scrubbed = sentry_module._scrub_event(event, {})
    assert scrubbed is not None
    assert scrubbed["message"] == "boom"
