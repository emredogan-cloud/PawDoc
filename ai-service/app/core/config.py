"""Application configuration loaded from environment variables.

All secrets and runtime knobs land here. Code MUST go through ``get_settings()``
rather than reading ``os.environ`` directly; centralising it keeps the secret
surface auditable and makes tests trivially overridable.

Notes:
- In production, Doppler injects env vars into the container at start.
- In local dev, ``.env`` is loaded by python-dotenv (optional — Docker Compose
  also injects via env_file).
- Pydantic validation happens at instantiation time, so missing/malformed env
  fails the process at boot rather than at first request.
"""

from __future__ import annotations

from enum import StrEnum
from functools import lru_cache
from typing import Literal

from pydantic import Field, HttpUrl, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class AppEnv(StrEnum):
    """Logical deployment environment.

    ``local`` is the only env where secrets may legitimately be empty (Phase 1
    integrations are not yet wired). ``dev`` and ``prod`` validate strictly.
    """

    LOCAL = "local"
    DEV = "dev"
    PROD = "prod"


LogLevel = Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]


class Settings(BaseSettings):
    """Top-level settings object.

    Field-level optionality reflects Phase 0 reality: most external integrations
    arrive in Phase 1. Phase 1 will tighten these from ``SecretStr | None`` to
    required ``SecretStr``.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_ignore_empty=True,
        case_sensitive=False,
        extra="ignore",
    )

    # ---- Runtime ------------------------------------------------------------
    app_env: AppEnv = Field(default=AppEnv.LOCAL, alias="APP_ENV")
    log_level: LogLevel = Field(default="INFO", alias="LOG_LEVEL")
    port: int = Field(default=8080, ge=1, le=65535, alias="PORT")

    # Comma-separated list of allowed CORS origins; "*" allowed only in local.
    allowed_origins: str = Field(default="http://localhost:*", alias="ALLOWED_ORIGINS")

    # ---- Supabase (Phase 1) -------------------------------------------------
    supabase_url: HttpUrl | None = Field(default=None, alias="SUPABASE_URL")
    supabase_service_role_key: SecretStr | None = Field(
        default=None, alias="SUPABASE_SERVICE_ROLE_KEY"
    )

    # ---- AI providers (Phase 1) ---------------------------------------------
    anthropic_api_key: SecretStr | None = Field(default=None, alias="ANTHROPIC_API_KEY")
    google_ai_api_key: SecretStr | None = Field(default=None, alias="GOOGLE_AI_API_KEY")
    openai_api_key: SecretStr | None = Field(default=None, alias="OPENAI_API_KEY")

    # ---- Cloudflare R2 (Phase 1) --------------------------------------------
    r2_account_id: str | None = Field(default=None, alias="R2_ACCOUNT_ID")
    r2_access_key_id: SecretStr | None = Field(default=None, alias="R2_ACCESS_KEY_ID")
    r2_secret_access_key: SecretStr | None = Field(default=None, alias="R2_SECRET_ACCESS_KEY")
    r2_bucket: str | None = Field(default=None, alias="R2_BUCKET")

    # ---- Upstash Redis (Phase 1, semantic cache) ----------------------------
    upstash_redis_rest_url: HttpUrl | None = Field(default=None, alias="UPSTASH_REDIS_REST_URL")
    upstash_redis_rest_token: SecretStr | None = Field(
        default=None, alias="UPSTASH_REDIS_REST_TOKEN"
    )

    # ---- Observability -------------------------------------------------------
    sentry_dsn: HttpUrl | None = Field(default=None, alias="SENTRY_DSN")
    sentry_environment: str = Field(default="local", alias="SENTRY_ENVIRONMENT")
    sentry_release: str = Field(default="0.1.0+local", alias="SENTRY_RELEASE")

    @property
    def is_local(self) -> bool:
        return self.app_env is AppEnv.LOCAL

    @property
    def is_production(self) -> bool:
        return self.app_env is AppEnv.PROD

    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",") if o.strip()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Singleton accessor.

    The ``lru_cache`` ensures we don't re-parse env on every request. Tests can
    clear it via ``get_settings.cache_clear()`` to override env-driven values.
    """
    return Settings()
