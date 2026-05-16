"""Tests for app.core.config."""

from __future__ import annotations

import pytest

from app.core.config import AppEnv, Settings, get_settings


def test_settings_defaults_to_local() -> None:
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.app_env is AppEnv.LOCAL
    assert settings.is_local
    assert not settings.is_production
    assert settings.port == 8080


def _prod_required_secrets(monkeypatch: pytest.MonkeyPatch) -> None:
    """Helper — set every prod-required secret so the B3 startup
    validator passes. Tests that want to exercise a single missing key
    delete it after calling this."""
    monkeypatch.setenv("INTERNAL_API_TOKEN", "token-1")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "anth-1")
    monkeypatch.setenv("GOOGLE_AI_API_KEY", "goog-1")
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "srv-1")


def test_settings_reads_env(monkeypatch: pytest.MonkeyPatch) -> None:
    _prod_required_secrets(monkeypatch)
    monkeypatch.setenv("APP_ENV", "prod")
    monkeypatch.setenv("LOG_LEVEL", "WARNING")
    monkeypatch.setenv("PORT", "9000")
    monkeypatch.setenv("ALLOWED_ORIGINS", "https://app.pawdoc.app, https://pawdoc.app")
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.app_env is AppEnv.PROD
    assert settings.is_production
    assert settings.log_level == "WARNING"
    assert settings.port == 9000
    assert settings.cors_origins() == ["https://app.pawdoc.app", "https://pawdoc.app"]


def test_settings_invalid_port_rejected(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("PORT", "99999")
    with pytest.raises(ValueError, match="less than or equal to 65535"):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_get_settings_is_cached() -> None:
    a = get_settings()
    b = get_settings()
    assert a is b


# ---------------------------------------------------------------------------
# Sprint B3 (F-OPS2 / H-9) — prod startup validator
# ---------------------------------------------------------------------------


def test_prod_missing_internal_token_refuses_boot(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _prod_required_secrets(monkeypatch)
    monkeypatch.delenv("INTERNAL_API_TOKEN", raising=False)
    monkeypatch.setenv("APP_ENV", "prod")
    with pytest.raises(ValueError, match="INTERNAL_API_TOKEN"):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_prod_missing_anthropic_refuses_boot(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _prod_required_secrets(monkeypatch)
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.setenv("APP_ENV", "prod")
    with pytest.raises(ValueError, match="ANTHROPIC_API_KEY"):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_prod_missing_google_refuses_boot(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _prod_required_secrets(monkeypatch)
    monkeypatch.delenv("GOOGLE_AI_API_KEY", raising=False)
    monkeypatch.setenv("APP_ENV", "prod")
    with pytest.raises(ValueError, match="GOOGLE_AI_API_KEY"):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_prod_missing_multiple_lists_them_all(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("APP_ENV", "prod")
    # No prod secrets set at all.
    with pytest.raises(ValueError) as excinfo:
        Settings(_env_file=None)  # type: ignore[call-arg]
    message = str(excinfo.value)
    for key in (
        "INTERNAL_API_TOKEN",
        "ANTHROPIC_API_KEY",
        "GOOGLE_AI_API_KEY",
        "SUPABASE_URL",
        "SUPABASE_SERVICE_ROLE_KEY",
    ):
        assert key in message


def test_local_env_tolerates_missing_secrets() -> None:
    # The default fixture clears the cache; no env set → LOCAL.
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.is_local
    assert settings.internal_api_token is None  # acceptable in local


def test_dev_env_tolerates_missing_secrets(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("APP_ENV", "dev")
    # B3's validator only fires in PROD — dev intentionally stays lenient
    # so engineers can hit a Supabase preview without every key.
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.app_env is AppEnv.DEV
    assert settings.internal_api_token is None
