"""Sentry SDK wiring.

The init function is the only entry point. It is safe to call without a
DSN (no-ops) so local development doesn't require a real Sentry account.

Discipline:
- ``before_send`` strips request bodies, auth headers, and query strings.
- The integration auto-captures FastAPI exceptions; we do not need to
  call ``capture_exception`` manually in the handlers.
- Releases are tagged with ``pawdoc-ai-service@<version>`` and an
  environment matching ``Settings.app_env``.
"""

from __future__ import annotations

from typing import Any, cast

import sentry_sdk
from sentry_sdk.integrations.asgi import SentryAsgiMiddleware
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.httpx import HttpxIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration

from app import __version__
from app.core.config import Settings
from app.core.logging import get_logger

log = get_logger(__name__)

# Idempotency latch. The `global` statement in `init_sentry` is the
# appropriate idiom for a module-level singleton flag; PLW0603 is the
# usual ruff-style hint, not a correctness concern here.
_initialized = False


def init_sentry(settings: Settings) -> bool:
    """Initialise Sentry. Returns True iff a DSN was configured.

    Safe to call multiple times — subsequent calls are no-ops.
    """
    global _initialized  # noqa: PLW0603 — module-singleton init latch
    if _initialized:
        return True

    if settings.sentry_dsn is None:
        log.info(
            "sentry_disabled",
            reason="SENTRY_DSN not configured",
            environment=settings.app_env.value,
        )
        return False

    sentry_sdk.init(
        dsn=str(settings.sentry_dsn),
        environment=settings.sentry_environment,
        release=f"pawdoc-ai-service@{__version__}",
        # Performance traces are useful but rate-limited at SaaS plans.
        # 10% sample is a sensible default; tune per traffic in Phase 2.
        traces_sample_rate=0.1,
        profiles_sample_rate=0.0,
        # We send our own structured exceptions; let Sentry capture only
        # those that escape our handlers.
        integrations=[
            FastApiIntegration(transaction_style="endpoint"),
            StarletteIntegration(),
            HttpxIntegration(),
        ],
        # Sentry typing exposes Event as a private class; cast keeps
        # mypy happy without us depending on the private symbol.
        before_send=cast(Any, _scrub_event),
        send_default_pii=False,
    )
    _initialized = True
    log.info(
        "sentry_initialized",
        environment=settings.sentry_environment,
        release=settings.sentry_release,
    )
    return True


def wrap_asgi_app(app: Any) -> Any:
    """Wrap a FastAPI app with the Sentry ASGI middleware.

    Idempotent on the wrapping side: calling twice still produces a working
    app, but the second wrap adds an extra (harmless) middleware layer. We
    avoid that by callers gating on ``init_sentry(...) is True``.
    """
    return SentryAsgiMiddleware(app)


def _scrub_event(event: dict[str, Any], hint: dict[str, Any]) -> dict[str, Any] | None:
    """Strip secrets/PII from the outgoing event.

    We're defensive — Sentry's default scrubber covers most patterns, but
    we also blank request bodies and auth headers entirely. Authentication
    tokens, request payloads, and user emails never leave the process.
    """
    if "request" in event and isinstance(event["request"], dict):
        req = event["request"]
        # Body is JSON containing user-supplied pet info — strip it.
        req.pop("data", None)
        # Query string can contain provider tokens in pathological cases.
        req.pop("query_string", None)
        # Headers: keep User-Agent (useful for triage) but strip everything
        # else that could be sensitive.
        headers = req.get("headers")
        if isinstance(headers, dict):
            allowed = {"user-agent", "x-request-id"}
            req["headers"] = {k: v for k, v in headers.items() if k.lower() in allowed}
    # User identifying info — we explicitly do not send user_id to Sentry
    # because the AI service receives only pet metadata (Phase 1B
    # decision). If a future change forwards user_id, it should land in
    # ``user.id`` only, never `username`/`email`.
    if "user" in event:
        event["user"] = {k: v for k, v in event["user"].items() if k in {"id"}}
    return event
