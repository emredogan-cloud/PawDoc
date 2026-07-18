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
        media: list[tuple[bytes, str]] | None = None,
        pet_context_block: str | None = None,
    ) -> dict:
        ...


class GeminiProvider:
    """Tier 2 — Gemini 2.0 Flash with JSON output enforcement."""

    name = "gemini"
    tier = 2

    def __init__(self, api_key: str, model: str = config.TIER2_MODEL) -> None:
        self._api_key = api_key
        self._model = model

    def analyze(
        self,
        system_prompt: str,
        user_prompt: str,
        media: list[tuple[bytes, str]] | None = None,
        pet_context_block: str | None = None,
    ) -> dict:
        model = self._model
        # B10 (evolution): TRUE role separation. The safety contract + per-pet
        # context ride in system_instruction; ONLY the owner-controlled text is
        # user content — 4,000 chars of untrusted input no longer shares a
        # string with the safety contract on the primary tier.
        system_sections = [system_prompt]
        if pet_context_block:
            system_sections.append(pet_context_block)
        system_text = "\n\n".join(system_sections)
        try:
            from google import genai  # lazy
            from google.genai import types

            # GAP-A1: attach REAL pixels (prefetched ONCE by the pipeline
            # through the guarded fetcher) as multimodal parts.
            parts = [
                types.Part.from_bytes(data=data, mime_type=mime)
                for data, mime in (media or [])
            ]
            contents = [*parts, user_prompt] if parts else user_prompt

            # GAP-A4: hard request timeout (ms) + bounded output so a hung/slow
            # Gemini call can't pin a thread or run up cost.
            client = genai.Client(
                api_key=self._api_key,
                http_options=types.HttpOptions(timeout=8000),
            )
            resp = client.models.generate_content(
                model=model,
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=system_text,
                    temperature=config.ANALYSIS_TEMPERATURE,
                    response_mime_type="application/json",
                    max_output_tokens=1024,
                ),
            )
            # Cost telemetry (R4): capture token usage when the SDK reports it.
            usage = getattr(resp, "usage_metadata", None)
            self.last_usage = {
                "input_tokens": getattr(usage, "prompt_token_count", None),
                "output_tokens": getattr(usage, "candidates_token_count", None),
            } if usage else None
            import json

            return json.loads(resp.text)
        except ProviderError:  # incl. MediaFetchError — propagate for safe degrade
            raise
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
        media: list[tuple[bytes, str]] | None = None,
        pet_context_block: str | None = None,
    ) -> dict:
        try:
            import base64

            import anthropic  # lazy

            # GAP-A1: attach REAL pixels (prefetched once by the pipeline) as
            # an image content block before the text; text-only requests keep
            # the plain-string content as before.
            if media:
                content: list | str = [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": mime,
                            "data": base64.standard_b64encode(data).decode("ascii"),
                        },
                    }
                    for data, mime in media
                ]
                content.append({"type": "text", "text": user_prompt})
            else:
                content = user_prompt

            # GAP-A4: 8s hard timeout + no SDK-level retries (the pipeline owns
            # the single retry / failover). The Anthropic default is 600s, which
            # would pin a thread and starve /health on the shared pool.
            client = anthropic.Anthropic(
                api_key=self._api_key, timeout=8.0, max_retries=0
            )
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
                messages=[{"role": "user", "content": content}],
            )
            usage = getattr(message, "usage", None)
            self.last_usage = {
                "input_tokens": getattr(usage, "input_tokens", None),
                "output_tokens": getattr(usage, "output_tokens", None),
            } if usage else None
            for block in message.content:
                if getattr(block, "type", None) == "tool_use":
                    return dict(block.input)
            raise ProviderError("claude: no tool_use block in response")
        except ProviderError:
            raise
        except Exception as exc:  # noqa: BLE001
            raise ProviderError(f"claude: {exc}") from exc


# JSON schema for Claude's structured tool output (mirrors AnalysisResult v2 —
# the action ladder; no differential, no condition names anywhere).
_ANALYSIS_TOOL = {
    "name": "report_triage",
    "description": "Return the pet-health observation and action guidance.",
    "input_schema": {
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": ["GET_HELP_NOW", "CALL_TODAY", "BOOK_VISIT", "WATCH_AND_RECHECK"],
            },
            "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0},
            "observation": {"type": "string"},
            "visible_symptoms": {"type": "array", "items": {"type": "string"}},
            "vets_look_for": {"type": "array", "items": {"type": "string"}},
            "watch_for": {"type": "array", "items": {"type": "string"}},
            "recommended_actions": {"type": "array", "items": {"type": "string"}},
            "urgency_timeframe": {"type": "string"},
            "recheck_hours": {"type": ["integer", "null"], "minimum": 1, "maximum": 336},
            "disclaimer_required": {"type": "boolean"},
        },
        "required": [
            "action", "confidence", "observation", "visible_symptoms",
            "vets_look_for", "watch_for", "recommended_actions",
            "urgency_timeframe", "disclaimer_required",
        ],
    },
}
