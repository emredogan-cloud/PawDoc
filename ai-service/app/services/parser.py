"""Structured-output parsing + validation.

The orchestrator never trusts raw provider text. Every Gemini/Claude
response goes through :func:`parse_provider_output` which:

1. ensures the payload is valid JSON,
2. coerces it into ``AnalysisProviderOutput`` via Pydantic,
3. returns a typed ``ParseSuccess`` or ``ParseFailure``.

The orchestrator's retry path uses the failure reason as a hint to bake
into a stricter retry prompt.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from pydantic import ValidationError

from app.core.logging import get_logger
from app.models.schemas import AnalysisProviderOutput

log = get_logger(__name__)


@dataclass(slots=True, frozen=True)
class ParseSuccess:
    value: AnalysisProviderOutput


@dataclass(slots=True, frozen=True)
class ParseFailure:
    reason: str
    raw: str


ParseResult = ParseSuccess | ParseFailure


def parse_provider_output(raw: str | dict[str, Any]) -> ParseResult:
    """Parse a provider's structured-output response.

    Accepts either:
    - a JSON string (the common Gemini case), or
    - a pre-parsed dict (the common Claude tool_use case where the SDK
      returns the tool input already deserialised).

    Always returns a ParseResult rather than raising — the orchestrator
    decides how to recover.
    """
    if isinstance(raw, str):
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            log.warning(
                "parser_invalid_json",
                error=str(e),
                snippet=raw[:200] if isinstance(raw, str) else None,
            )
            return ParseFailure(reason=f"invalid_json: {e.msg}", raw=raw)
    else:
        data = raw

    if not isinstance(data, dict):
        return ParseFailure(reason="response_not_object", raw=str(raw)[:500])

    try:
        validated = AnalysisProviderOutput(**data)
    except ValidationError as e:
        log.warning("parser_schema_violation", errors=e.errors())
        return ParseFailure(reason=f"schema_violation: {_summarise(e)}", raw=str(data)[:500])

    return ParseSuccess(value=validated)


def _summarise(err: ValidationError) -> str:
    parts: list[str] = []
    for e in err.errors():
        loc = ".".join(str(x) for x in e.get("loc", ()))
        parts.append(f"{loc}: {e.get('msg', '')}")
    return "; ".join(parts[:5])
