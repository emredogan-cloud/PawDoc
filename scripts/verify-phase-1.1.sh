#!/usr/bin/env bash
# =============================================================================
# verify-phase-1.1.sh — App Skeleton + Auth + Data Layer checklist.
# Runs the headless-verifiable checks (Flutter analyze/test, RLS isolation,
# schema/edge-function/contract presence). Device + real-JWT sign-in + Sentry
# event are MANUAL (founder, needs a device + live Supabase).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/mobile"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
skip()   { printf '\033[0;33mSKIP\033[0m  %s\n' "$*"; }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }

hr; echo "Phase 1.1 — App Skeleton, Auth & Data Layer"; hr

# --- Schema migration present with CR #20 FK + CR #2 RLS corrections ----------
schema="$ROOT/supabase/migrations/20260527010000_initial_schema.sql"
rls="$ROOT/supabase/migrations/20260527010001_rls_policies.sql"
if grep -q 'references auth.users (id) on delete cascade' "$schema" \
   && [ "$(grep -c 'on delete cascade' "$schema")" -ge 6 ]; then
  pass "schema migration: FK ON DELETE semantics applied (CR #20)"
else
  fail "schema migration: FK ON DELETE corrections missing"
fi
if [ "$(grep -c 'with check' "$rls")" -ge 6 ] && grep -q 'enable row level security' "$rls"; then
  pass "RLS migration: WITH CHECK + per-table policies present (CR #2)"
else
  fail "RLS migration: corrected policies missing"
fi

# --- Edge Function verifies its signature (CR #21) ---------------------------
fn="$ROOT/supabase/functions/auth-webhook/index.ts"
if [ -f "$fn" ] && grep -q 'wh.verify' "$fn" && grep -q 'invalid signature' "$fn"; then
  pass "auth-webhook verifies signature before provisioning (CR #21)"
else
  fail "auth-webhook missing signature verification"
fi

# --- AnalysisResult contract frozen (Dart + doc) -----------------------------
if [ -f "$MOBILE/lib/src/models/analysis_result.dart" ] \
   && [ -f "$ROOT/docs/contracts/ANALYSIS_RESULT.md" ]; then
  pass "AnalysisResult contract present (Dart binding + spec, CR #16)"
else
  fail "AnalysisResult contract missing"
fi

# --- Flutter analyze + test --------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  ( cd "$MOBILE" && flutter analyze >/tmp/pawdoc_analyze.log 2>&1 ) \
    && pass "flutter analyze: no issues" \
    || fail "flutter analyze failed — see /tmp/pawdoc_analyze.log"
  ( cd "$MOBILE" && flutter test >/tmp/pawdoc_fluttertest.log 2>&1 ) \
    && pass "flutter test: $(grep -oE 'All tests passed|[0-9]+ tests? passed' /tmp/pawdoc_fluttertest.log | tail -1)" \
    || fail "flutter test failed — see /tmp/pawdoc_fluttertest.log"
else
  skip "flutter not installed — analyze/test not run"
fi

# --- RLS isolation (real Postgres) -------------------------------------------
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
  "$ROOT/scripts/test-rls.sh" >/tmp/pawdoc_rls.log 2>&1 \
    && pass "RLS isolation test passed (cross-user read/write blocked)" \
    || fail "RLS isolation test failed — see /tmp/pawdoc_rls.log"
else
  skip "docker unavailable — run ./scripts/test-rls.sh to verify RLS"
fi

# --- MANUAL ------------------------------------------------------------------
manual "App runs to a signed-in state on a real iOS simulator + Android emulator (needs --dart-define Supabase config)."
manual "Email + Apple sign-in each create a public.users row via /auth-webhook (runbook 13)."
manual "Sentry receives a deliberately-thrown test exception."

hr
if [ "$fails" -eq 0 ]; then
  echo "Verifiable checks GREEN. Confirm MANUAL items on a device for full DoD."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
