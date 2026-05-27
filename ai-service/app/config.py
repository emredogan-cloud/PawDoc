"""Phase 1.3 configuration. Model IDs are standardized (Critical Review #17) —
never use marketing names like "Claude 3.5 Sonnet"."""
from __future__ import annotations

import os

# --- Model IDs (CR #17) ------------------------------------------------------
TIER2_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
TIER3_MODEL = os.getenv("CLAUDE_MODEL", "claude-sonnet-4-6")

# --- Pipeline thresholds (per roadmap §AI Tier Architecture) -----------------
ANALYSIS_TEMPERATURE = 0.1          # MUST be 0.1 on every health-analysis call
CONFIDENCE_ROUTE_THRESHOLD = 0.85   # Tier-2 confidence > this -> accept; else escalate to Tier 3
CONFIDENCE_FLOOR = 0.60             # below this -> "insufficient information" (never fabricate)
FREE_TIER_MONTHLY_LIMIT = 3

# --- Secrets / runtime flags (read from env; never hardcode) -----------------
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
GOOGLE_AI_API_KEY = os.getenv("GOOGLE_AI_API_KEY", "")
UPSTASH_REDIS_REST_URL = os.getenv("UPSTASH_REDIS_REST_URL", "")
UPSTASH_REDIS_REST_TOKEN = os.getenv("UPSTASH_REDIS_REST_TOKEN", "")

# CR #19: kill-switch. A static env fallback; the dynamic (no-redeploy) flag is
# read from the cache at request time by the pipeline.
AI_KILL_SWITCH_ENV = os.getenv("AI_KILL_SWITCH", "").lower() in ("1", "true", "yes")
KILL_SWITCH_CACHE_KEY = "pawdoc:ai_kill_switch"
