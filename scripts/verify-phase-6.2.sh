#!/usr/bin/env bash
# =============================================================================
# verify-phase-6.2.sh — Outcome Feedback Loop & Data Foundation (Phase 6.2).
#
# Asserts the moat-seed pipeline is end-to-end safe:
#   * outcome CHECK constraint exists on analysis_feedback,
#   * the FP/FN/TP/TN classification view + summary exist + lockdowns,
#   * export pipeline strips PII (positive allowlist + assert_no_pii guard),
#   * pg + pytest batteries pass.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MIG="$ROOT/supabase/migrations/20260528020000_accuracy_views.sql"
PG_TEST="$ROOT/supabase/tests/accuracy_views.sql"
TX_PY="$ROOT/ai-service/app/training_export.py"
CLI="$ROOT/scripts/export-training-dataset.py"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 6.2 — Outcome Feedback Loop & Data Foundation"; hr

# --- Outcome categorization (DB + UI lock-step) ------------------------------
have "$MIG"                                           "accuracy_views migration"
check "CHECK constraint on analysis_feedback.outcome" "analysis_feedback_outcome_check" "$MIG"
check "CHECK allows the 5 canonical values"            "'resolved_on_own'" "$MIG"
check "CHECK allows 'vet_confirmed'"                   "'vet_confirmed'" "$MIG"
check "CHECK allows 'vet_said_nothing'"                "'vet_said_nothing'" "$MIG"
check "CHECK allows 'still_monitoring'"                "'still_monitoring'" "$MIG"
check "CHECK allows 'other'"                           "'other'" "$MIG"
check "FollowUpBanner exposes vet_said_nothing chip"   "followup_vet_said_nothing" "$ROOT/mobile/lib/src/feedback/followup_banner.dart"

# --- Accuracy views (FP/FN/TP/TN + lockdowns) --------------------------------
check "view_accuracy_signals exists"                   "create or replace view public.view_accuracy_signals" "$MIG"
check "view_accuracy_summary exists"                   "create or replace view public.view_accuracy_summary" "$MIG"
check "FP proxy: EMERGENCY + vet_said_nothing|resolved" "false_positive_proxy" "$MIG"
check "FN proxy: NORMAL + vet_confirmed"               "false_negative_proxy" "$MIG"
check "TP / TN proxies present"                        "true_positive_proxy" "$MIG"
check "Lockdown: REVOKE from anon/authenticated"       "revoke all on public.view_accuracy_signals from public, anon, authenticated" "$MIG"
check "Lockdown: GRANT service_role"                   "grant select on public.view_accuracy_signals to service_role" "$MIG"

have "$PG_TEST"                                        "accuracy_views pg test"
have "$ROOT/scripts/test-accuracy-views.sh"            "accuracy_views test harness"

# --- Dataset export pipeline (PII strip) -------------------------------------
have "$TX_PY"                                          "training_export module"
have "$CLI"                                            "export CLI script"
check "Allowlist: CONTEXT_ALLOWED"                     "CONTEXT_ALLOWED" "$TX_PY"
check "Allowlist: AI_ALLOWED"                          "AI_ALLOWED" "$TX_PY"
check "Allowlist: OUTCOME_ALLOWED"                     "OUTCOME_ALLOWED" "$TX_PY"
check "Defense: PII_BLOCKLIST"                         "PII_BLOCKLIST" "$TX_PY"
check "Defense: assert_no_pii"                         "def assert_no_pii" "$TX_PY"
check "CLI requires SUPABASE_SERVICE_ROLE_KEY"         "SUPABASE_SERVICE_ROLE_KEY" "$CLI"
check ".gitignore catches *.jsonl exports"             "^\*\.jsonl$" "$ROOT/.gitignore"
have "$ROOT/ai-service/tests/test_training_export.py"  "training_export pytest"

# --- Batteries ---------------------------------------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp62.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp62.log 2>&1); then
    pass "ruff + pytest green (incl. training_export + golden-set)"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp62.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions"/_shared/*.test.mjs >/tmp/pawdoc_node62.log 2>&1; then
    pass "node --test (_shared) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node62.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

if command -v docker >/dev/null 2>&1; then
  if "$ROOT/scripts/test-accuracy-views.sh" >/tmp/pawdoc_av62.log 2>&1; then
    pass "accuracy_views pg test green"
  else
    fail "accuracy_views pg test failed (see /tmp/pawdoc_av62.log)"
  fi
else
  manual "Run ./scripts/test-accuracy-views.sh (needs Docker)."
fi

if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an62.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an62.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt62.log 2>&1); then
    pass "flutter test green (incl. 5-canonical-outcomes test)"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt62.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL (founder) --------------------------------------------------------
manual "Apply 20260528020000_accuracy_views.sql on Supabase (\`supabase db push\`). The views are admin-only (SQL editor / service_role)."
manual "Periodic export (e.g. weekly): SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY in env, then run scripts/export-training-dataset.py. Output lands in /tmp by default; *.jsonl is gitignored. Review FN-proxy rows and add the incidents to ai-service/tests/golden_set.json."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 6.2 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
