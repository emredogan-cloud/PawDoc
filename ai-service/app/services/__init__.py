"""Service layer: orchestration, provider clients, safety, cache, parser.

Phase 0 leaves this package empty by design. Phase 1 will add:
- orchestrator.py    tier routing
- gemini_client.py   Tier 2 (Gemini 2.0 Flash)
- claude_client.py   Tier 3/4 (Claude Sonnet / Opus)
- safety.py          hardcoded emergency-keyword override
- cache.py           pgvector + Redis semantic cache
- parser.py          structured-output schema validation
"""
