#!/usr/bin/env bash
# =============================================================================
# verify-phase-3.3.sh — Referral System, Rewards & Fraud Controls checklist.
# Structural checks (RPC fraud logic, lockdowns, reward wiring, analytics) plus
# the real batteries: node --test, the referral fraud-control pg test (Docker),
# flutter analyze/test, and ruff/pytest. The two-account flow on a live project
# is MANUAL (see the sub-PR report).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIG="$ROOT/supabase/migrations/20260527030000_referrals.sql"
FN="$ROOT/supabase/functions"
M="$ROOT/mobile/lib/src"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 3.3 — Referral System, Rewards & Fraud Controls"; hr

# --- Files present -----------------------------------------------------------
have "$MIG"                                "Referral migration"
have "$ROOT/supabase/tests/referral.sql"   "Referral fraud-control test"
have "$ROOT/scripts/test-referral.sh"      "Referral test harness"
have "$FN/claim-referral/index.ts"         "/claim-referral Edge Function"
have "$FN/_shared/referral.mjs"            "Referral result helper"
have "$M/referral/referral_service.dart"   "Flutter ReferralService"

# --- RPC + fraud logic -------------------------------------------------------
check "claim_referral RPC defined"             'function public.claim_referral' "$MIG"
check "RPC is transactional/atomic (SECURITY DEFINER plpgsql)" 'security definer' "$MIG"
check "Race prevention: locks the claimer row FOR UPDATE" 'for update' "$MIG"
check "No self-referral guard"                 'self_referral' "$MIG"
check "One-claim guard (referred_by_user_id)"  'referred_by_user_id' "$MIG"
check "Double-claim DB guard (UNIQUE referred_user_id)" 'referrals_referred_user_id_key unique' "$MIG"
check "Reward: bonus_analyses granted"         'bonus_analyses = bonus_analyses \+ 3' "$MIG"

# --- Lockdowns (strict rule) -------------------------------------------------
check "RPC locked to service_role"             'grant execute on function' "$MIG"
check "RPC revoked from anon/authenticated"    'revoke all on function public.claim_referral' "$MIG"
check "referrals not client-writable"          'revoke insert, update, delete on public.referrals' "$MIG"
check "users UPDATE revoked from clients"       'revoke update on public.users from anon, authenticated' "$MIG"
check "only one_signal_player_id re-granted"   'grant update \(one_signal_player_id\)' "$MIG"

# --- Edge Function -----------------------------------------------------------
check "Edge calls the claim_referral RPC"      'rpc\("claim_referral"' "$FN/claim-referral/index.ts"
check "claimer_id taken from the JWT (not body)" 'claimer_id: user.id' "$FN/claim-referral/index.ts"
check "claim-referral requires a JWT"          '\[functions.claim-referral\]' "$ROOT/supabase/config.toml"

# --- Reward allocation -------------------------------------------------------
check "Free-tier honors a bonus pool"          'bonus = 0' "$FN/_shared/free_tier.mjs"
check "analyze passes + persists bonus_analyses" 'bonus_analyses: decision.newBonus' "$FN/analyze/index.ts"

# --- Analytics ---------------------------------------------------------------
check "Analytics: referral_code_submitted"     'referral_code_submitted' "$M/analytics/analytics.dart"
check "Analytics: referral_success"            'referral_success' "$M/analytics/analytics.dart"
check "Analytics: referral_fraud_prevented"    'referral_fraud_prevented' "$M/analytics/analytics.dart"
check "Referral screen has a claim button"     'referral_claim_button' "$M/referral/referral_screen.dart"

# --- node --test -------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
  if node --test "$FN"/_shared/*.test.mjs >/tmp/pawdoc_node33.log 2>&1; then
    pass "node --test (_shared) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node33.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

# --- Referral fraud-control pg test (Docker) ---------------------------------
if command -v docker >/dev/null 2>&1; then
  if "$ROOT/scripts/test-referral.sh" >/tmp/pawdoc_referral33.log 2>&1; then
    pass "referral RPC test green (reward-once, self/double/invalid blocked, lockdowns)"
  else
    fail "referral test failed (see /tmp/pawdoc_referral33.log)"
  fi
else
  manual "Run ./scripts/test-referral.sh (needs Docker)."
fi

# --- AI service ruff + pytest (unaffected this phase; run for safety) --------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_ruff33.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_ruff33.log 2>&1); then
    pass "ruff + pytest green"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_ruff33.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

# --- Flutter analyze + test --------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an33.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an33.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt33.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt33.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL ------------------------------------------------------------------
manual "Two-account flow on a live/local Supabase: see sub-PR report §3 for the recipe."
manual "Deno typecheck of claim-referral (supabase CI) — deno not run here."
manual "Optional: a '+1 month premium' reward variant needs the RevenueCat server API (deferred)."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 3.3 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
