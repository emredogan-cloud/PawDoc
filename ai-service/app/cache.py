"""Result cache + kill-switch flag (CR #19).

InMemoryCache is the default (and what tests use). UpstashCache talks to the
Upstash Redis REST API and is used in production when configured. The pipeline
reads the kill-switch flag from the cache at request time so it can be flipped
WITHOUT a redeploy.
"""
from __future__ import annotations

from typing import Protocol

from . import config


class Cache(Protocol):
    def get(self, key: str) -> str | None: ...
    def set(self, key: str, value: str, ttl_seconds: int | None = None) -> None: ...


class InMemoryCache:
    def __init__(self) -> None:
        self._store: dict[str, str] = {}

    def get(self, key: str) -> str | None:
        return self._store.get(key)

    def set(self, key: str, value: str, ttl_seconds: int | None = None) -> None:
        self._store[key] = value


class UpstashCache:
    """Minimal Upstash Redis REST client (lazy httpx import)."""

    def __init__(self, url: str, token: str) -> None:
        self._url = url.rstrip("/")
        self._token = token

    def _request(self, *parts: str) -> dict:
        import httpx  # lazy

        resp = httpx.post(
            f"{self._url}/{'/'.join(parts)}",
            headers={"Authorization": f"Bearer {self._token}"},
            timeout=2.0,
        )
        resp.raise_for_status()
        return resp.json()

    def get(self, key: str) -> str | None:
        try:
            return self._request("get", key).get("result")
        except Exception:
            return None  # cache must never break the request path

    def set(self, key: str, value: str, ttl_seconds: int | None = None) -> None:
        try:
            if ttl_seconds:
                self._request("set", key, value, "EX", str(ttl_seconds))
            else:
                self._request("set", key, value)
        except Exception:
            pass


def make_cache() -> Cache:
    if config.UPSTASH_REDIS_REST_URL and config.UPSTASH_REDIS_REST_TOKEN:
        return UpstashCache(config.UPSTASH_REDIS_REST_URL, config.UPSTASH_REDIS_REST_TOKEN)
    return InMemoryCache()


def is_ai_disabled(cache: Cache) -> bool:
    """CR #19 kill-switch: true if the env flag is set OR the dynamic cache flag
    is on. Lets ops disable the AI path without an app release or redeploy."""
    if config.AI_KILL_SWITCH_ENV:
        return True
    return cache.get(config.KILL_SWITCH_CACHE_KEY) in ("1", "true", "on")
