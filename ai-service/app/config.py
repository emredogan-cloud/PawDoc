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

# --- Assistant (Next Evolution Phase 4) — conversational surface -------------
# NOT triage: the 0.1 temperature rule is for health-analysis calls; the
# assistant is a guardrailed companion (no diagnosis / no dosing / emergency
# override before any call) and keeps a deliberately low-but-warmer 0.3.
ASSISTANT_MODEL = os.getenv("ASSISTANT_MODEL", TIER3_MODEL)
ASSISTANT_TEMPERATURE = 0.3
ASSISTANT_MAX_TOKENS = 1500
ASSISTANT_HISTORY_LIMIT = 20     # turns per request window (EF sends the tail)
ASSISTANT_TIMEOUT_SECONDS = 45.0  # whole-stream budget on the provider call

# --- Secrets / runtime flags (read from env; never hardcode) -----------------
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
GOOGLE_AI_API_KEY = os.getenv("GOOGLE_AI_API_KEY", "")
UPSTASH_REDIS_REST_URL = os.getenv("UPSTASH_REDIS_REST_URL", "")
UPSTASH_REDIS_REST_TOKEN = os.getenv("UPSTASH_REDIS_REST_TOKEN", "")

# CR #19: kill-switch. A static env fallback; the dynamic (no-redeploy) flag is
# read from the cache at request time by the pipeline.
AI_KILL_SWITCH_ENV = os.getenv("AI_KILL_SWITCH", "").lower() in ("1", "true", "yes")
KILL_SWITCH_CACHE_KEY = "pawdoc:ai_kill_switch"

# --- Trust boundary (Phase A) ------------------------------------------------
# The AI service is INTERNAL: only the Supabase Edge Functions may call it, and
# they present `Authorization: Bearer <AI_SERVICE_TOKEN>`. Verified constant-time
# in main.require_service_auth. Empty by default so local dev + the unit suite
# run unauthenticated; in production the token MUST be set or the service fails
# closed (refuses every request) rather than serving the pipeline open.
AI_SERVICE_TOKEN = os.getenv("AI_SERVICE_TOKEN", "")
# Fly sets FLY_APP_NAME on every machine, so "running on Fly" == production.
# AI_ENV is an explicit override for any non-Fly production host.
IS_PRODUCTION = bool(os.getenv("FLY_APP_NAME")) or os.getenv("AI_ENV", "").lower() in (
    "prod",
    "production",
    "prd",
)

# GAP-D2: error monitoring. Empty by default => Sentry is a no-op in dev/test.
# Set as a Fly secret on the production app so outages become visible.
SENTRY_DSN = os.getenv("SENTRY_DSN", "")
