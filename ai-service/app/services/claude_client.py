"""Anthropic Claude client — Tier 3 (and cross-verify) of the AI pipeline.

We talk to the Anthropic Messages API directly via httpx. The structured-
output discipline is enforced by the ``tool_use`` pattern with
``tool_choice = {"type": "tool", "name": "submit_analysis"}``: Claude is
forced to call the tool, and the tool's JSON schema mirrors our
``AnalysisProviderOutput`` shape.

Prompt caching is wired by attaching ``cache_control`` to the static
portion of the system prompt. We pass that as the first system block; the
per-request variable text (pet context, breed risk notes, user input) goes
to the ``user`` message and is NOT cached.
"""

from __future__ import annotations

from typing import Any

import httpx

from app.core.config import Settings
from app.core.exceptions import UpstreamError
from app.core.logging import get_logger

log = get_logger(__name__)

_ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
_ANTHROPIC_VERSION = "2023-06-01"

# Mirrors AnalysisProviderOutput. Embedded literal — the parser still
# validates everything that comes back, so this is purely guidance to
# Claude.
_TOOL_DEFINITION: dict[str, Any] = {
    "name": "submit_analysis",
    "description": "Submit the structured pet health triage analysis.",
    "input_schema": {
        "type": "object",
        "properties": {
            "triage_level": {
                "type": "string",
                "enum": ["EMERGENCY", "MONITOR", "NORMAL"],
            },
            "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0},
            "primary_concern": {"type": "string", "minLength": 10, "maxLength": 500},
            "visible_symptoms": {
                "type": "array",
                "items": {"type": "string"},
                "maxItems": 20,
            },
            "differential": {
                "type": "array",
                "items": {"type": "string"},
                "maxItems": 10,
            },
            "recommended_actions": {
                "type": "array",
                "items": {"type": "string"},
                "minItems": 1,
                "maxItems": 10,
            },
            "urgency_timeframe": {"type": "string", "minLength": 3, "maxLength": 120},
        },
        "required": [
            "triage_level",
            "confidence",
            "primary_concern",
            "recommended_actions",
            "urgency_timeframe",
        ],
    },
}


class ClaudeClient:
    """Async client for the Anthropic Messages endpoint, tool-use mode."""

    def __init__(self, settings: Settings, *, client: httpx.AsyncClient | None = None) -> None:
        self._settings = settings
        self._client = client or httpx.AsyncClient(timeout=settings.claude_timeout_s)

    async def aclose(self) -> None:
        await self._client.aclose()

    async def analyze(
        self,
        system_prompt_static: str,
        user_prompt: str,
        *,
        max_tokens: int = 1024,
    ) -> dict[str, Any]:
        """Call Claude and return the tool input dict.

        The dict is the model's structured output BEFORE Pydantic validation;
        the parser layer validates and may reject.
        """
        if self._settings.anthropic_api_key is None:
            raise UpstreamError("Anthropic API key not configured.")

        headers = {
            "x-api-key": self._settings.anthropic_api_key.get_secret_value(),
            "anthropic-version": _ANTHROPIC_VERSION,
            "content-type": "application/json",
        }
        body: dict[str, Any] = {
            "model": self._settings.claude_model,
            "max_tokens": max_tokens,
            "temperature": 0.1,
            "system": [
                {
                    "type": "text",
                    "text": system_prompt_static,
                    "cache_control": {"type": "ephemeral"},
                }
            ],
            "tools": [_TOOL_DEFINITION],
            "tool_choice": {"type": "tool", "name": "submit_analysis"},
            "messages": [{"role": "user", "content": user_prompt}],
        }

        last_err: Exception | None = None
        for attempt in (1, 2):
            try:
                resp = await self._client.post(_ANTHROPIC_URL, headers=headers, json=body)
            except httpx.RequestError as e:
                last_err = e
                log.warning("claude_request_error", attempt=attempt, error=str(e))
                continue

            if resp.status_code == 200:
                return _extract_tool_input(resp.json())
            if 500 <= resp.status_code < 600 and attempt == 1:
                log.warning("claude_5xx_retrying", status=resp.status_code)
                continue
            log.error("claude_non_2xx", status=resp.status_code, body=resp.text[:500])
            raise UpstreamError(f"Claude returned HTTP {resp.status_code}.")

        raise UpstreamError(f"Claude request failed after retries: {last_err}")


def _extract_tool_input(payload: dict[str, Any]) -> dict[str, Any]:
    """Pull the tool_use block out of Claude's response.

    Claude's response shape under tool_choice is:
        { "content": [{"type": "tool_use", "name": "submit_analysis", "input": {...}}], ... }
    """
    blocks = payload.get("content", [])
    if not isinstance(blocks, list):
        raise UpstreamError("Claude response content is not a list.")

    for block in blocks:
        if isinstance(block, dict) and block.get("type") == "tool_use":
            tool_input = block.get("input")
            if not isinstance(tool_input, dict):
                raise UpstreamError("Claude tool_use input is not a dict.")
            return tool_input

    raise UpstreamError("Claude did not return a tool_use block.")
