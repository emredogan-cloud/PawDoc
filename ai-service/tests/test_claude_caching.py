"""Anthropic prompt caching structure (Phase 6.1).

Asserts the ClaudeProvider builds TWO ephemeral cache breakpoints — the static
safety contract + the per-pet personalization block — so repeat checks for the
same pet within the 5-minute TTL pay only 25% of input cost on the cached
prefix. The test exercises the pure builder, not the live API.
"""
from app.providers import ClaudeProvider


def _provider():
    # No real key needed — `build_system_blocks` is pure.
    return ClaudeProvider(api_key="not-used")


def test_only_static_block_when_no_pet_context():
    blocks = _provider().build_system_blocks("STATIC SAFETY CONTRACT", None)
    assert len(blocks) == 1
    assert blocks[0]["text"] == "STATIC SAFETY CONTRACT"
    assert blocks[0]["cache_control"] == {"type": "ephemeral"}


def test_two_cache_breakpoints_when_pet_context_present():
    blocks = _provider().build_system_blocks(
        "STATIC SAFETY CONTRACT",
        "Pet profile:\nSpecies: dog\nBreed: Labrador",
    )
    assert len(blocks) == 2
    # Order matters: static contract first (largest, hottest cache), pet block
    # second so the cache-write breakpoint lands AFTER it.
    assert blocks[0]["text"] == "STATIC SAFETY CONTRACT"
    assert "Pet profile" in blocks[1]["text"]
    # BOTH blocks declare ephemeral cache_control — repeats within 5 minutes
    # for the same pet hit both.
    for b in blocks:
        assert b["type"] == "text"
        assert b["cache_control"] == {"type": "ephemeral"}


def test_pet_context_block_text_round_trips_verbatim():
    """The pipeline assembles the block once and the provider must ship it
    byte-for-byte — any reformatting would silently invalidate the cache."""
    pet_block = "Pet profile:\nSpecies: cat\nAge (years): 7.5\n\nRecent analyses (last 30 days, newest first):\n  - [2026-05-22] MONITOR: vomiting"
    blocks = _provider().build_system_blocks("STATIC", pet_block)
    assert blocks[1]["text"] == pet_block
