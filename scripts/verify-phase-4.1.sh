#!/usr/bin/env bash
# =============================================================================
# verify-phase-4.1.sh — Experimentation Infrastructure (Phase 4.1).
# Structural checks (resilient feature flags + deterministic identify, in-app
# feedback to analysis_feedback, the 72h follow-up eligibility RPC) + the real
# batteries: node, the follow-up + RLS pg tests (Docker), ruff/pytest, flutter
# analyze/test. PostHog flag config + A/B dashboards are founder-side (MANUAL).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIG="$ROOT/supabase/migrations/20260527050000_followup.sql"
M="$ROOT/mobile/lib/src"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 4.1 — Experimentation Infrastructure"; hr

# --- Files present -----------------------------------------------------------
have "$MIG"                                       "Follow-up eligibility migration"
have "$ROOT/supabase/tests/followup.sql"          "Follow-up pg test"
have "$ROOT/scripts/test-followup.sh"             "Follow-up test harness"
have "$M/experiments/feature_flags.dart"          "Feature flags wrapper"
have "$M/feedback/analysis_feedback_repository.dart" "Feedback repository"
have "$M/feedback/result_feedback_widget.dart"    "Result feedback widget"
have "$M/feedback/followup_banner.dart"           "72h follow-up banner"
have "$M/feedback/pending_followup.dart"          "Follow-up eligibility provider"

# --- Feature flags: resilient + deterministic --------------------------------
check "Flags default to CONTROL on error"       'return defaultValue' "$M/experiments/feature_flags.dart"
check "Flag key for the A/B (paywall timing)"   "paywallTiming = 'paywall-timing'" "$M/experiments/feature_flags.dart"
check "Deterministic bucketing: identify(uid)"  'Posthog\(\).identify\(userId: uid\)' "$ROOT/mobile/lib/main.dart"

# --- In-app feedback ---------------------------------------------------------
check "Thumbs up control"                       'feedback_thumbs_up' "$M/feedback/result_feedback_widget.dart"
check "Thumbs down control"                     'feedback_thumbs_down' "$M/feedback/result_feedback_widget.dart"
check "Optional comment on thumbs-down"         'feedback_comment' "$M/feedback/result_feedback_widget.dart"
check "Writes to analysis_feedback"             "from\('analysis_feedback'\)" "$M/feedback/analysis_feedback_repository.dart"
check "Feedback row carries no user_id (RLS via parent)" 'ownership is enforced by RLS' "$M/feedback/analysis_feedback_repository.dart"
check "Result screen renders the feedback widget" 'ResultFeedbackWidget' "$M/analysis/result_screen.dart"

# --- 72h follow-up -----------------------------------------------------------
check "RPC: eligibility query defined"          'function public.pending_followup_analyses' "$MIG"
check "RPC: older than 72 hours"                "interval '72 hours'" "$MIG"
check "RPC: only analyses with NO feedback"     'not exists' "$MIG"
check "RPC: RLS-scoped (security invoker)"      'security invoker' "$MIG"
check "Client calls the eligibility RPC"        "rpc\('pending_followup_analyses'\)" "$M/feedback/pending_followup.dart"
check "Home shows the follow-up banner"         'FollowUpBanner' "$ROOT/mobile/lib/src/home/home_screen.dart"
check "Banner snoozes on 'Not now' (no nag)"    'followup_not_now' "$M/feedback/followup_banner.dart"

# --- analysis_feedback RLS proof ---------------------------------------------
check "RLS policy exists (CR #2)"               'analysis_feedback_owner' "$ROOT/supabase/migrations/20260527010001_rls_policies.sql"
check "RLS test: feedback insert controls"      'analysis_feedback WRITE' "$ROOT/supabase/tests/rls_isolation.sql"

# --- Analytics ---------------------------------------------------------------
check "Analytics: feedback_submitted"           'feedback_submitted' "$M/analytics/analytics.dart"

# --- node --test -------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions"/_shared/*.test.mjs >/tmp/pawdoc_node41.log 2>&1; then
    pass "node --test (_shared) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node41.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

# --- pg tests (Docker) -------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  if "$ROOT/scripts/test-followup.sh" >/tmp/pawdoc_fu41.log 2>&1; then
    pass "follow-up eligibility pg test green (>72h + no-feedback, RLS-scoped)"
  else
    fail "follow-up pg test failed (see /tmp/pawdoc_fu41.log)"
  fi
  if "$ROOT/scripts/test-rls.sh" >/tmp/pawdoc_rls41.log 2>&1; then
    pass "RLS test green (incl. analysis_feedback insert controls)"
  else
    fail "RLS test failed (see /tmp/pawdoc_rls41.log)"
  fi
else
  manual "Run ./scripts/test-followup.sh and ./scripts/test-rls.sh (need Docker)."
fi

# --- AI service (unaffected; run for safety) ---------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp41.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp41.log 2>&1); then
    pass "ruff + pytest green"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp41.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

# --- Flutter -----------------------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an41.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an41.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt41.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt41.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL ------------------------------------------------------------------
manual "Create the PostHog feature flag(s) (e.g. paywall-timing) + A/B dashboards in the PostHog UI."
manual "On device: thumbs up/down on a result persists to analysis_feedback; 72h banner appears for an eligible analysis and fires once."
manual "Verify variant stability: same user -> same bucket across sessions (PostHog identified by uid)."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 4.1 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
