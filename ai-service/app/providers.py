"""AI provider abstraction. Real providers lazy-import their SDKs so the unit
tests (which inject fakes) don't need the SDKs or any API keys.

Both providers run at temperature 0.1 (config.ANALYSIS_TEMPERATURE) and return a
dict matching the AnalysisResult contract; the pipeline parses + validates it."""
from __future__ import annotations

from typing import Protocol

from . import config


class ProviderError(RuntimeError):
    """Wraps any provider/transport failure so the pipeline can retry/degrade."""


class AIProvider(Protocol):
    name: str
    tier: int

    def analyze(
        self,
        system_prompt: str,
        user_prompt: str,
        image_url: str | None = None,
        frame_urls: list[str] | None = None,
        pet_context_block: str | None = None,
    ) -> dict:
        ...


class GeminiProvider:
    """Tier 2 — Gemini 2.0 Flash with JSON output enforcement. Video (Phase 3.2)
    routes here and uses the pinned VIDEO_MODEL (CR #17)."""

    name = "gemini"
    tier = 2

    def __init__(
        self,
        api_key: str,
        model: str = config.TIER2_MODEL,
        video_model: str = config.VIDEO_MODEL,
    ) -> None:
        self._api_key = api_key
        self._model = model
        self._video_model = video_model

    def select_model(self, frame_urls: list[str] | None) -> str:
        """Video keyframes -> the explicitly pinned video model; otherwise the
        standard Tier-2 model. Pinning prevents version drift (CR #17). Pure, so
        the routing is unit-tested without invoking the SDK."""
        return self._video_model if frame_urls else self._model

    def analyze(
        self,
        system_prompt: str,
        user_prompt: str,
        image_url: str | None = None,
        frame_urls: list[str] | None = None,
        pet_context_block: str | None = None,
    ) -> dict:
        model = self.select_model(frame_urls)
        # Gemini has no equivalent of Anthropic's ephemeral prompt cache, so we
        # concatenate the static + per-pet + per-check parts into one stream.
        # Static parts still go first so they hit the model's implicit KV cache
        # when the SDK / server side optimizes for repeated prefixes.
        sections = [system_prompt]
        if pet_context_block:
            sections.append(pet_context_block)
        sections.append(user_prompt)
        contents = "\n\n".join(sections)
        try:
            from google import genai  # lazy
            from google.genai import types

            client = genai.Client(api_key=self._api_key)
            resp = client.models.generate_content(
                model=model,
                contents=contents,
                config=types.GenerateContentConfig(
                    temperature=config.ANALYSIS_TEMPERATURE,
                    response_mime_type="application/json",
                ),
            )
            import json

            return json.loads(resp.text)
        except Exception as exc:  # noqa: BLE001 — normalize all SDK errors
            raise ProviderError(f"gemini: {exc}") from exc


class ClaudeProvider:
    """Tier 3 — Claude Sonnet with structured output via tool_use + prompt caching."""

    name = "claude"
    tier = 3

    def __init__(self, api_key: str, model: str = config.TIER3_MODEL) -> None:
        self._api_key = api_key
        self._model = model

    def build_system_blocks(self, system_prompt: str, pet_context_block: str | None):
        """Pure builder for the `system` field — two ephemeral cache breakpoints:
        block #1 is the static safety contract, block #2 (when present) is the
        per-pet personalization context (Phase 6.1). Exposed so tests can assert
        the cache structure without calling the API."""
        blocks: list[dict] = [
            {
                "type": "text",
                "text": system_prompt,
                "cache_control": {"type": "ephemeral"},
            },
        ]
        if pet_context_block:
            blocks.append(
                {
                    "type": "text",
                    "text": pet_context_block,
                    "cache_control": {"type": "ephemeral"},
                }
            )
        return blocks

    def analyze(
        self,
        system_prompt: str,
        user_prompt: str,
        image_url: str | None = None,
        frame_urls: list[str] | None = None,
        pet_context_block: str | None = None,
    ) -> dict:
        try:
            import anthropic  # lazy

            client = anthropic.Anthropic(api_key=self._api_key)
            message = client.messages.create(
                model=self._model,
                max_tokens=1024,
                temperature=config.ANALYSIS_TEMPERATURE,
                # Phase 6.1 — two ephemeral cache breakpoints: static safety
                # contract + per-pet personalization block. Repeated checks for
                # the same pet within 5 min pay 25% of input cost on the cached
                # portion (Anthropic prompt caching, 5-min TTL).
                system=self.build_system_blocks(system_prompt, pet_context_block),
                tools=[_ANALYSIS_TOOL],
                tool_choice={"type": "tool", "name": "report_triage"},
                messages=[{"role": "user", "content": user_prompt}],
            )
            for block in message.content:
                if getattr(block, "type", None) == "tool_use":
                    return dict(block.input)
            raise ProviderError("claude: no tool_use block in response")
        except ProviderError:
            raise
        except Exception as exc:  # noqa: BLE001
            raise ProviderError(f"claude: {exc}") from exc


# JSON schema for Claude's structured tool output (mirrors AnalysisResult).
_ANALYSIS_TOOL = {
    "name": "report_triage",
    "description": "Return the pet-health triage assessment.",
    "input_schema": {
        "type": "object",
        "properties": {
            "triage_level": {"type": "string", "enum": ["EMERGENCY", "MONITOR", "NORMAL"]},
            "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0},
            "primary_concern": {"type": "string"},
            "visible_symptoms": {"type": "array", "items": {"type": "string"}},
            "differential": {"type": "array", "items": {"type": "string"}},
            "recommended_actions": {"type": "array", "items": {"type": "string"}},
            "urgency_timeframe": {"type": "string"},
            "disclaimer_required": {"type": "boolean"},
        },
        "required": [
            "triage_level", "confidence", "primary_concern", "visible_symptoms",
            "differential", "recommended_actions", "urgency_timeframe", "disclaimer_required",
        ],
    },
}
