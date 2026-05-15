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


def test_settings_reads_env(monkeypatch: pytest.MonkeyPatch) -> None:
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
