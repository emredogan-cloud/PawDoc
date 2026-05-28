#!/usr/bin/env bash
# =============================================================================
# verify-phase-6.1.sh — Personalization Engine (Phase 6.1).
#
# SAFETY GATE: CR #2-eval — the Golden Set must run with 0 false-negatives on
# EMERGENCY. This script structurally asserts the personalization wiring AND
# runs the eval harness as the final gate.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AI="$ROOT/ai-service/app"
EDGE="$ROOT/supabase/functions/analyze/index.ts"
GOLDEN="$ROOT/ai-service/tests/golden_set.json"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 6.1 — Personalization Engine"; hr

# --- Context-assembly layer --------------------------------------------------
check "AnalyzeRequest.recent_analyses field"          "recent_analyses: list\[dict\]" "$AI/models.py"
check "AnalyzeRequest.recent_events field"            "recent_events: list\[dict\]" "$AI/models.py"
check "Pipeline builds the personalization block"     "build_personalization_block" "$AI/pipeline.py"
check "Pipeline passes pet_context_block to provider" "pet_context_block=pet_context" "$AI/pipeline.py"
check "Edge selects analyses for the pet (last 30d)"  "from\(\"analyses\"\)" "$EDGE"
check "Edge selects health_events for the pet (last 30d)" "from\(\"health_events\"\)" "$EDGE"
check "Edge ships recent_analyses to AI"              "recent_analyses: recentAnalyses" "$EDGE"
check "Edge ships recent_events to AI"                "recent_events: recentEvents" "$EDGE"
check "Edge history fetch is best-effort (try/catch)" "Personalization is best-effort" "$EDGE"

# --- Prompt builder ----------------------------------------------------------
check "build_personalization_block exists"            "def build_personalization_block" "$AI/prompts.py"
check "build_user_prompt is dynamic-only"             "Dynamic per-check portion" "$AI/prompts.py"
check "Recent-history caps to keep token cost bounded" "RECENT_ANALYSES_CAP" "$AI/prompts.py"
check "History framed as background, not ground truth" "background context, NOT as ground truth" "$AI/prompts.py"

# --- Anthropic prompt caching (two breakpoints) ------------------------------
check "ClaudeProvider.build_system_blocks exposed"    "def build_system_blocks" "$AI/providers.py"
check "Static safety prompt is cache_control ephemeral" "cache_control" "$AI/providers.py"
check "Pet-context block also carries ephemeral cache" "blocks.append" "$AI/providers.py"
check "Provider Protocol takes pet_context_block"     "pet_context_block: str \| None" "$AI/providers.py"

# --- Golden Set + eval harness (CR #2-eval) ----------------------------------
have "$GOLDEN"                                        "golden_set.json present"
have "$ROOT/ai-service/app/eval_harness.py"           "eval harness module"
have "$ROOT/scripts/run-eval.py"                      "eval runner script"
have "$ROOT/ai-service/tests/test_golden_set.py"      "golden-set pytest binding"
check "Golden set has EN emergency case"              '"emergency_en_global_keyword"' "$GOLDEN"
check "Golden set has DE emergency case"              '"emergency_de_global_keyword"' "$GOLDEN"
check "Golden set has species-specific EN case"       '"emergency_species_specific_rabbit_en"' "$GOLDEN"
check "Golden set has species-specific DE case"       '"emergency_species_specific_rabbit_de"' "$GOLDEN"
check "Golden set has AI-detected EMERGENCY case"     '"emergency_ai_detected_cross_verified"' "$GOLDEN"
check "Golden set has personalized-history EMERGENCY" '"emergency_with_personalized_history"' "$GOLDEN"
check "Golden set has CR #4 borderline-NORMAL bias"   '"borderline_normal_biased_to_monitor"' "$GOLDEN"
check "Golden set has degraded / kill-switch case"    '"kill_switch_degraded"' "$GOLDEN"
check "Golden set has moderation-rejected case"       '"moderation_rejected_image"' "$GOLDEN"
check "Eval runner enforces 0 EMERGENCY FN gate"      "false_negatives_on_emergency" "$ROOT/scripts/run-eval.py"

# --- Run the actual harness (the real safety gate) ---------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if "$ROOT/ai-service/.venv/bin/python" "$ROOT/scripts/run-eval.py" >/tmp/pawdoc_eval61.log 2>&1; then
    pass "golden-set eval green (0 EMERGENCY FN, all cases pass)"
  else
    fail "golden-set eval FAILED (see /tmp/pawdoc_eval61.log)"
  fi
else
  manual "Run ai-service/.venv/bin/python scripts/run-eval.py"
fi

# --- Batteries ---------------------------------------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp61.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp61.log 2>&1); then
    pass "ruff + pytest green (incl. golden-set binding)"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp61.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions"/_shared/*.test.mjs >/tmp/pawdoc_node61.log 2>&1; then
    pass "node --test (_shared) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node61.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an61.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an61.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt61.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt61.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL (founder) --------------------------------------------------------
manual "When promoting to production, verify Anthropic prompt-cache hit-rate on a sampled day (Fly logs / Anthropic console) — should see >0 cache reads on second+ checks per pet within 5 min."
manual "Founder review: add new cases to golden_set.json as real incidents surface (it's a living dataset). Re-run scripts/run-eval.py before every major prompt change."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 6.1 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
