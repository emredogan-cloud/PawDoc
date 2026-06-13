"""GAP-D2: ai-service Sentry init is a safe no-op without a DSN.

The live "simulated failure -> Sentry event" acceptance needs a real DSN +
project (founder). Here we prove the guard: no DSN => Sentry stays off and the
init never raises, so dev/test/CI run cleanly.
"""
from app import config
from app.main import _SENTRY_ENABLED, _init_sentry


def test_sentry_off_in_test_env():
    # No SENTRY_DSN is configured in the test environment.
    assert _SENTRY_ENABLED is False


def test_init_sentry_noop_without_dsn(monkeypatch):
    monkeypatch.setattr(config, "SENTRY_DSN", "")
    assert _init_sentry() is False
