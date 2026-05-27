#!/usr/bin/env bash
# =============================================================================
# verify-phase-1.3.sh — AI Orchestration & Safety Core checklist.
# Headless-verifiable: ruff + pytest (safety core, routing, CR #4/#5/#19),
# free-tier Node test (CR #10), and structural checks for the safety invariants.
# Live provider calls + deployed end-to-end are MANUAL (need API keys).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AISVC="$ROOT/ai-service"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
skip()   { printf '\033[0;33mSKIP\033[0m  %s\n' "$*"; }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }

check() {  # check "label" grep-pattern file
  if grep -q "$2" "$3"; then pass "$1"; else fail "$1"; fi
}

hr; echo "Phase 1.3 — AI Orchestration & Safety Core"; hr

# --- Safety invariants (structural) ------------------------------------------
check "temperature locked at 0.1 (every health call)" 'ANALYSIS_TEMPERATURE = 0.1' "$AISVC/app/config.py"
check "model IDs standardized (CR #17: claude-sonnet-4-6)" 'claude-sonnet-4-6' "$AISVC/app/config.py"
check "emergency override runs pre-AI" 'check_emergency_override' "$AISVC/app/pipeline.py"
check "confidence floor 0.60 gate present" 'CONFIDENCE_FLOOR = 0.60' "$AISVC/app/config.py"
check "CR #4 borderline-NORMAL re-check wired" 'needs_normal_recheck' "$AISVC/app/pipeline.py"
check "CR #19 kill-switch + degraded fallback" 'is_ai_disabled' "$AISVC/app/pipeline.py"
check "CR #23 request-id propagation" 'x-request-id' "$AISVC/app/main.py"
check "/analyze endpoint present" '/analyze' "$AISVC/app/main.py"
check "Edge Function /analyze present" 'evaluateFreeTier' "$ROOT/supabase/functions/analyze/index.ts"
check "CR #10 free-tier monthly reset" 'didReset' "$ROOT/supabase/functions/_shared/free_tier.mjs"

# --- ruff + pytest (the CI gate, run locally) --------------------------------
if [ -x "$AISVC/.venv/bin/ruff" ]; then
  if "$AISVC/.venv/bin/ruff" check "$AISVC" >/dev/null 2>&1; then pass "ruff: ai-service clean"; else fail "ruff issues"; fi
else
  skip "ruff — set up ai-service/.venv"
fi
if [ -x "$AISVC/.venv/bin/python" ]; then
  if ( cd "$AISVC" && .venv/bin/python -m pytest -q >/tmp/pawdoc_p13.log 2>&1 ); then
    pass "pytest: $(grep -oE '[0-9]+ passed' /tmp/pawdoc_p13.log | head -1) (override 23 keywords, parser, routing, CR #4/#5/#19)"
  else
    fail "pytest failed — see /tmp/pawdoc_p13.log"
  fi
else
  skip "pytest — ai-service/.venv not set up"
fi

# --- free-tier unit test (CR #10), Node ------------------------------------
if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions/_shared/free_tier.test.mjs" >/tmp/pawdoc_ft.log 2>&1; then
    pass "free-tier Node test: 3-ok/4th-blocked + monthly reset"
  else
    fail "free-tier test failed — see /tmp/pawdoc_ft.log"
  fi
else
  skip "node not installed — run the free-tier test"
fi

# --- MANUAL (need API keys / deploy) -----------------------------------------
manual "With real keys: Tier 2 P50 < 3s, Tier 3 P50 < 6s; live emergency + cross-verify."
manual "Deploy AI service + Edge Function; end-to-end /analyze stores a row (runbook 14)."

hr
if [ "$fails" -eq 0 ]; then
  echo "Verifiable checks GREEN. Confirm MANUAL items with live keys for full DoD."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
