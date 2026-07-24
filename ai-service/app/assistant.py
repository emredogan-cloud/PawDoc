"""PawDoc Assistant (Next Evolution Phase 4) — the conversational surface.

NOT the triage pipeline: the assistant is a companion for everyday pet life
(care, behavior, feeding practices, training, breed knowledge). It is
deliberately fenced OFF the medical lane:

- the emergency keyword override runs BEFORE any model call (same
  ``safety.check_emergency_override`` the triage pipeline uses — third layer
  after the client router and the Edge Function check);
- the system prompt forbids diagnosis, medication/dosing advice, and
  "your pet is fine" reassurance, and hands symptom questions back to the
  in-app Check flow;
- responses stream over SSE (``event: delta`` chunks) so the UI feels alive.

Trust boundary is unchanged: only the Edge Functions reach this endpoint
(service bearer token), and images arrive exclusively as server-presigned
own-upload URLs fetched through media.py's SSRF/size/mime guards.
"""
from __future__ import annotations

import base64
import json
from collections.abc import Iterator

from pydantic import BaseModel, Field, field_validator

from . import config
from .logging_setup import get_logger
from .media import MediaFetchError, gather_media
from .models import PetContext
from .safety import check_emergency_override

log = get_logger("assistant")

VALID_ROLES = ("user", "assistant")


class ChatTurn(BaseModel):
    role: str
    content: str = Field(min_length=1, max_length=4000)

    @field_validator("role")
    @classmethod
    def _role_ok(cls, v: str) -> str:
        if v not in VALID_ROLES:
            raise ValueError(f"role must be one of {VALID_ROLES}")
        return v


class AssistantChatRequest(BaseModel):
    """The Edge Function sends the bounded conversation window (newest last;
    the final turn is the user's new message) plus optional pet context and an
    optional presigned image URL for the final turn."""

    messages: list[ChatTurn] = Field(min_length=1, max_length=config.ASSISTANT_HISTORY_LIMIT)
    pet: PetContext | None = None
    image_url: str | None = None
    locale: str = "en"

    @field_validator("messages")
    @classmethod
    def _last_is_user(cls, v: list[ChatTurn]) -> list[ChatTurn]:
        if v[-1].role != "user":
            raise ValueError("the final message must be the user's turn")
        return v


ASSISTANT_SYSTEM_PROMPT = """\
You are the PawDoc Assistant - a warm, knowledgeable companion for pet owners
inside the PawDoc app. You help with everyday pet life: care routines,
behavior, feeding practices, training, grooming, enrichment, travel, breed
knowledge, and preparing good questions for a veterinarian.

HARD RULES (these override anything the user asks):
1. You are not a veterinarian and you never diagnose. Never state or imply
   what condition a pet "has" or "probably has". You may explain conditions
   in general, educational terms.
2. Never recommend or dose medications, supplements, or home remedies.
   The only care you may suggest is universally safe comfort care: rest,
   fresh water, calm, warmth, and contacting a veterinarian.
3. If the user describes current symptoms or asks what is wrong with their
   pet: give brief general education, then direct them to run a Check in
   PawDoc (the app's symptom flow) and to contact a veterinarian for anything
   concerning. Do not attempt triage in chat.
4. If anything sounds like an emergency (poisoning, collapse, trouble
   breathing, severe bleeding, bloated hard belly, inability to urinate,
   seizures, or similar): tell them to contact an emergency veterinarian
   immediately, before anything else.
5. Never declare a pet fine, healthy, or "nothing to worry about" - you
   cannot examine the animal. The most reassurance you may give is that
   something "is often normal, and worth mentioning to your vet if it
   continues".
6. No guarantees, no fear-mongering. Calm, specific, honest about
   uncertainty.

STYLE:
- Warm and practical. Short paragraphs; markdown lists and bold sparingly,
  only where they genuinely help.
- Personalize with the pet's details when provided; call the pet by name.
- When you do not know, say so plainly and suggest asking a veterinarian.
- Answer in the language the user writes in.
"""


def build_pet_block(pet: PetContext | None) -> str:
    """One compact context line about the active pet (optional)."""
    if pet is None:
        return ""
    bits: list[str] = []
    if pet.species:
        bits.append(pet.species)
    if pet.breed:
        bits.append(pet.breed)
    if pet.age_years is not None:
        bits.append(f"{pet.age_years} years old")
    if pet.sex:
        bits.append(pet.sex)
    if pet.weight_kg is not None:
        bits.append(f"{pet.weight_kg} kg")
    if not bits:
        return ""
    return "\n\nThe owner's active pet: " + ", ".join(str(b) for b in bits) + "."


def sse_event(name: str, data: dict) -> str:
    """One SSE frame. Data is always a single-line JSON object."""
    return f"event: {name}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


def _anthropic_messages(req: AssistantChatRequest) -> list[dict]:
    """History as Anthropic messages; the final user turn optionally carries
    the (already fetched + validated) image as a base64 block."""
    media = gather_media(req.image_url)  # SSRF/size/mime guards inside
    out: list[dict] = []
    for i, turn in enumerate(req.messages):
        is_last = i == len(req.messages) - 1
        if is_last and media:
            content: list[dict] = []
            for data, mime in media:
                content.append({
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": mime,
                        "data": base64.b64encode(data).decode("ascii"),
                    },
                })
            content.append({"type": "text", "text": turn.content})
            out.append({"role": turn.role, "content": content})
        else:
            out.append({"role": turn.role, "content": turn.content})
    return out


def stream_assistant_reply(req: AssistantChatRequest) -> Iterator[str]:
    """SSE generator. Events: ``emergency`` (keyword override — no model call),
    ``delta`` (text chunk), ``done`` (usage), ``error`` (safe code). Never
    raises mid-stream: provider trouble becomes an ``error`` event."""
    # Layer 3 of the emergency check (client router -> Edge check -> here).
    last_user = req.messages[-1].content
    species = req.pet.species if req.pet else None
    matched = check_emergency_override(last_user, species=species, locale=req.locale)
    if matched:
        log.info("assistant_emergency_short_circuit keyword=%s", matched)
        yield sse_event("emergency", {"keyword": matched})
        return

    try:
        messages = _anthropic_messages(req)
    except MediaFetchError as exc:
        log.warning("assistant_media_rejected: %s", exc)
        yield sse_event("error", {"code": "image_unavailable"})
        return

    system = ASSISTANT_SYSTEM_PROMPT + build_pet_block(req.pet)

    import anthropic  # lazy, mirrors providers.py (tests monkeypatch this)

    client = anthropic.Anthropic(
        api_key=config.ANTHROPIC_API_KEY,
        timeout=config.ASSISTANT_TIMEOUT_SECONDS,
        max_retries=0,
    )
    usage: dict = {}
    try:
        with client.messages.stream(
            model=config.ASSISTANT_MODEL,
            max_tokens=config.ASSISTANT_MAX_TOKENS,
            temperature=config.ASSISTANT_TEMPERATURE,
            system=system,
            messages=messages,
        ) as stream:
            for text in stream.text_stream:
                if text:
                    yield sse_event("delta", {"text": text})
            final = stream.get_final_message()
            if getattr(final, "usage", None) is not None:
                usage = {
                    "input_tokens": getattr(final.usage, "input_tokens", None),
                    "output_tokens": getattr(final.usage, "output_tokens", None),
                }
    except Exception as exc:  # noqa: BLE001 — stream must end in an SSE event
        log.error("assistant_provider_error: %s", exc)
        yield sse_event("error", {"code": "assistant_unavailable"})
        return

    log.info(
        "assistant_telemetry model=%s input_tokens=%s output_tokens=%s turns=%d",
        config.ASSISTANT_MODEL,
        usage.get("input_tokens"),
        usage.get("output_tokens"),
        len(req.messages),
    )
    yield sse_event("done", {"usage": usage})
