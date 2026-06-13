"""Server-side media fetch for multimodal triage (GAP-A1).

The providers must attach REAL pixels to the model call, not a text claim that
"an image is provided". This module fetches the presigned R2 media bytes,
bounded by scheme, host shape, size, timeout and content-type so a slow or
hostile URL can neither hang the service nor pull arbitrary content.

GAP-A2 (SSRF) layers a strict host allowlist on top of this; as a first line of
defense this module already refuses non-https and IP-literal hosts and does not
follow redirects.
"""
from __future__ import annotations

import ipaddress
from urllib.parse import urlparse

import httpx

from .providers import ProviderError

# Content types we will attach to a model (mirrors the upload ext allowlist).
ALLOWED_MIME = {"image/jpeg", "image/png", "image/webp"}
_EXT_MIME = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}
MAX_MEDIA_BYTES = 8_000_000  # 8 MB hard cap per item
MAX_FRAMES = 6  # video keyframe cap (mirrors models.py / A4)


class MediaFetchError(ProviderError):
    """Media could not be fetched/validated. The pipeline degrades to a SAFE
    result (MONITOR, never NORMAL) — we never analyze an image we couldn't read."""


def _is_ip_literal(host: str) -> bool:
    try:
        ipaddress.ip_address(host)
        return True
    except ValueError:
        return False


def _guess_mime(url: str, header_ct: str | None) -> str | None:
    ct = (header_ct or "").split(";")[0].strip().lower()
    if ct in ALLOWED_MIME:
        return ct
    path = urlparse(url).path.lower()
    for ext, mime in _EXT_MIME.items():
        if path.endswith(ext):
            return mime
    return None


def fetch_media(
    url: str, *, max_bytes: int = MAX_MEDIA_BYTES, timeout: float = 8.0
) -> tuple[bytes, str]:
    """Fetch and validate one media item. Returns (bytes, mime_type).

    Raises [MediaFetchError] on: non-https scheme, missing/IP-literal host,
    non-200, redirect, timeout, oversize body, empty body, or a content-type
    outside [ALLOWED_MIME]. Streams the body and aborts past ``max_bytes`` so a
    hostile endpoint can't stream unbounded data.
    """
    parsed = urlparse(url)
    if parsed.scheme != "https":
        raise MediaFetchError(f"refusing non-https media url (scheme={parsed.scheme!r})")
    host = parsed.hostname or ""
    if not host or _is_ip_literal(host):
        raise MediaFetchError("refusing media url with missing or IP-literal host")
    try:
        with httpx.Client(timeout=timeout, follow_redirects=False) as client:
            with client.stream("GET", url) as resp:
                if resp.status_code != 200:
                    raise MediaFetchError(f"media fetch status {resp.status_code}")
                declared = resp.headers.get("content-length")
                if declared and declared.isdigit() and int(declared) > max_bytes:
                    raise MediaFetchError(
                        f"media too large (declared {declared} > {max_bytes} bytes)"
                    )
                chunks: list[bytes] = []
                total = 0
                for chunk in resp.iter_bytes():
                    total += len(chunk)
                    if total > max_bytes:
                        raise MediaFetchError(
                            f"media too large (>{max_bytes} bytes streamed)"
                        )
                    chunks.append(chunk)
                data = b"".join(chunks)
                mime = _guess_mime(url, resp.headers.get("content-type"))
    except MediaFetchError:
        raise
    except httpx.HTTPError as exc:
        raise MediaFetchError(f"media transport error: {exc}") from exc
    if not data:
        raise MediaFetchError("media body empty")
    if mime is None:
        raise MediaFetchError("media content-type not in allowlist")
    return data, mime


def gather_media(
    image_url: str | None, frame_urls: list[str] | None
) -> list[tuple[bytes, str]]:
    """Fetch all media items for a request: up to [MAX_FRAMES] video frames, or a
    single image. Returns [] for a text-only request. Any item failing fetch
    raises [MediaFetchError] (the pipeline turns that into a safe degrade)."""
    if frame_urls:
        return [fetch_media(u) for u in frame_urls[:MAX_FRAMES]]
    if image_url:
        return [fetch_media(image_url)]
    return []
