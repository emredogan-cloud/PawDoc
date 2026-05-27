"""CR #8 — lightweight NSFW/content moderation for uploaded images.

The pipeline calls a moderator BEFORE the main analysis. If the image is unsafe,
analysis is refused and the Edge Function deletes the stored R2 object.

Moderators are injectable so the gate is unit-testable with a fake; the real
GeminiModerator does a cheap vision safety check (lazy SDK import)."""
from __future__ import annotations

from typing import Protocol

from . import config


class ImageModerator(Protocol):
    def is_safe(self, image_url: str) -> bool: ...


class AllowAllModerator:
    """Default when no image / no provider key (text-only analyses are unaffected)."""

    def is_safe(self, image_url: str) -> bool:
        return True


class GeminiModerator:
    """Cheap NSFW gate: asks Gemini to confirm the image is a non-explicit photo
    of an animal, and relies on the provider's safety filtering. Fails CLOSED
    (treats errors/blocks as unsafe)."""

    def __init__(self, api_key: str, model: str = config.TIER2_MODEL) -> None:
        self._api_key = api_key
        self._model = model

    def is_safe(self, image_url: str) -> bool:
        try:
            import httpx  # lazy
            from google import genai
            from google.genai import types

            image_bytes = httpx.get(image_url, timeout=5.0).content
            client = genai.Client(api_key=self._api_key)
            resp = client.models.generate_content(
                model=self._model,
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                    "Answer only YES if this is a non-explicit photo of an animal or pet, "
                    "otherwise NO.",
                ],
                config=types.GenerateContentConfig(temperature=0.0),
            )
            return (resp.text or "").strip().upper().startswith("YES")
        except Exception:
            return False  # fail closed — unsafe/unknown content is rejected
