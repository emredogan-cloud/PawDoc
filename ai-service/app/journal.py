"""AI Health Journal (Phase 5.3) — weekly narrative synthesis.

Resilient by design (CR #5): the OpenAI provider returns None on ANY failure
(no API key, timeout, SDK error) and the cron Edge Function skips that pet
without crashing the system or writing partial data. The prompt has strict
anti-hallucination guards: do NOT diagnose new conditions, do NOT override
prior triage advice, describe ONLY what is in the provided history.
"""
from __future__ import annotations

from typing import Protocol

from . import config
from .models import JournalRequest

JOURNAL_SYSTEM_PROMPT = """You are PawDoc's Health Journal writer.

Given a pet's recent triage results and logged events from the past week,
write a SHORT (4–7 sentences), empathetic, plain-language summary of how the
pet's week went.

CRITICAL safety rules (these override anything else):
- DO NOT diagnose a new condition or invent symptoms not in the history.
- DO NOT override or contradict previous triage advice — refer to it as given.
- DO NOT prescribe a specific treatment, medication, or dose.
- Describe ONLY what is in the provided history; if it is sparse, say so
  honestly (\"not much logged this week\") rather than guessing.
- Tone: calm, supportive, plain language. No alarmism, no false reassurance.

End with one short, gentle reminder: this is information, not a veterinary diagnosis."""


def build_journal_prompt(req: JournalRequest) -> str:
    """Compact, deterministic user prompt from the pet's last 7 days."""
    pet = req.pet
    lines = [f"Pet: {pet.species}" + (f" ({pet.breed})" if pet.breed else "")]
    if pet.age_years is not None:
        lines.append(f"Age (years): {pet.age_years}")
    lines.append(f"Week starting: {req.week_start_date}")

    if req.analyses:
        lines.append("Recent triage results:")
        for a in req.analyses:
            lines.append(
                f"- {a.get('created_at', '?')}: {a.get('triage_level', '?')} — {a.get('primary_concern', '')}"
            )
    else:
        lines.append("Recent triage results: none logged this week.")

    if req.events:
        lines.append("Logged events:")
        for e in req.events:
            note = f" — {e.get('notes')}" if e.get("notes") else ""
            lines.append(f"- {e.get('event_date', '?')}: {e.get('event_type', '?')}{note}")
    else:
        lines.append("Logged events: none.")

    lines.append("Write the 4–7 sentence weekly summary as instructed by the system message.")
    return "\n".join(lines)


class JournalProvider(Protocol):
    def generate(self, request: JournalRequest) -> str | None: ...


class OpenAIJournalProvider:
    """GPT-4o(-mini) via the OpenAI SDK. Lazy-imported so tests don't need the
    package installed. Returns None on ANY failure — the caller logs + skips."""

    def __init__(self, api_key: str, model: str = config.OPENAI_MODEL) -> None:
        self._api_key = api_key
        self._model = model

    def generate(self, request: JournalRequest) -> str | None:
        if not self._api_key:
            return None
        try:
            import openai  # lazy

            client = openai.OpenAI(api_key=self._api_key, timeout=config.JOURNAL_TIMEOUT_SECONDS)
            resp = client.chat.completions.create(
                model=self._model,
                temperature=config.JOURNAL_TEMPERATURE,
                max_tokens=config.JOURNAL_MAX_TOKENS,
                messages=[
                    {"role": "system", "content": JOURNAL_SYSTEM_PROMPT},
                    {"role": "user", "content": build_journal_prompt(request)},
                ],
            )
            text = (resp.choices[0].message.content or "").strip()
            return text or None
        except Exception:  # noqa: BLE001 — resilience: any failure -> None (CR #5)
            return None


class NullJournalProvider:
    """Used when OpenAI isn't configured. Always returns None."""

    def generate(self, request: JournalRequest) -> str | None:  # noqa: ARG002
        return None


def make_journal_provider() -> JournalProvider:
    if config.OPENAI_API_KEY:
        return OpenAIJournalProvider(config.OPENAI_API_KEY)
    return NullJournalProvider()
