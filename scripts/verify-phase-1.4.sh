#!/usr/bin/env bash
# =============================================================================
# verify-phase-1.4.sh — Result UX, Monetization & End-to-End QA checklist.
# Headless-verifiable: flutter analyze/test (incl. result screens + mocked e2e),
# Node monetization tests, and structural checks for the EMERGENCY trust rule,
# the signed RevenueCat webhook, and API-injected disclaimers.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/mobile"
FN="$ROOT/supabase/functions"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
skip()   { printf '\033[0;33mSKIP\033[0m  %s\n' "$*"; }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -q "$2" "$3"; then pass "$1"; else fail "$1"; fi; }

hr; echo "Phase 1.4 — Result UX, Monetization & End-to-End QA"; hr

# --- EMERGENCY never paywalled (the critical rule) ---------------------------
check "Edge Function: EMERGENCY bypasses the free-tier gate" 'EMERGENCY IS NEVER PAYWALLED' "$FN/analyze/index.ts"
check "Edge Function: emergency text checked before gating" 'isEmergencyText' "$FN/analyze/index.ts"
check "Client policy: paywall never shown after EMERGENCY" 'c.lastTriageWasEmergency) return false' "$MOBILE/lib/src/monetization/paywall_policy.dart"

# --- Integration: 1.2 input -> 1.3 /analyze ----------------------------------
check "client analysis service calls /analyze" "functions.invoke('analyze'" "$MOBILE/lib/src/analysis/analysis_service.dart"
check "Edge Function presigns GET URL from the storage key" 'presignGet' "$FN/analyze/index.ts"

# --- Result UX ---------------------------------------------------------------
check "loading screen has 4 rotating messages" 'Putting together your guidance' "$MOBILE/lib/src/analysis/loading_screen.dart"
check "standard result badge (LIKELY NORMAL)" 'LIKELY NORMAL' "$MOBILE/lib/src/analysis/result_screen.dart"
check "EMERGENCY screen + acknowledgment gate" 'emergency_ack_checkbox' "$MOBILE/lib/src/analysis/emergency_result_screen.dart"
check "API-injected disclaimer gates the UI banner" 'disclaimerRequired' "$MOBILE/lib/src/analysis/result_screen.dart"
check "Share on NORMAL results" 'result_share' "$MOBILE/lib/src/analysis/result_screen.dart"

# --- Monetization + webhook --------------------------------------------------
check "revenuecat-webhook verifies the secret (CR #21)" 'unauthorized' "$FN/revenuecat-webhook/index.ts"
check "revenuecat-webhook maps entitlements" 'entitlementStatusFromEvent' "$FN/revenuecat-webhook/index.ts"
check "revenuecat-webhook verify_jwt disabled" 'functions.revenuecat-webhook' "$ROOT/supabase/config.toml"
check "paywall is annual-first" 'paywall_annual' "$MOBILE/lib/src/monetization/paywall_screen.dart"

# --- Analytics ---------------------------------------------------------------
for ev in analysis_completed result_viewed emergency_triggered paywall_shown trial_started subscription_converted; do
  check "analytics event: $ev" "$ev" "$MOBILE/lib/src/analytics/analytics.dart"
done

# --- flutter analyze + test --------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  if ( cd "$MOBILE" && flutter analyze >/tmp/pawdoc_a14.log 2>&1 ); then pass "flutter analyze: no issues"; else fail "flutter analyze failed (/tmp/pawdoc_a14.log)"; fi
  if ( cd "$MOBILE" && flutter test >/tmp/pawdoc_t14.log 2>&1 ); then
    pass "flutter test: $(grep -oE 'All tests passed|[0-9]+ tests? passed' /tmp/pawdoc_t14.log | tail -1)"
  else
    fail "flutter test failed (/tmp/pawdoc_t14.log)"
  fi
else
  skip "flutter not installed"
fi

# --- Node monetization tests -------------------------------------------------
if command -v node >/dev/null 2>&1; then
  if node --test "$FN/_shared/monetization.test.mjs" >/tmp/pawdoc_m14.log 2>&1; then pass "monetization Node tests (emergency keywords + entitlement map)"; else fail "monetization tests failed"; fi
else
  skip "node not installed"
fi

# --- MANUAL ------------------------------------------------------------------
manual "Device e2e: capture/text -> /analyze -> loading -> result (all 3 triage levels)."
manual "Confirm the paywall appears only AFTER the first analysis, never during emergency/onboarding, <=1/day."
manual "RevenueCat: configure products; a test purchase flips users.subscription_status via the webhook."

hr
if [ "$fails" -eq 0 ]; then
  echo "Verifiable checks GREEN. Confirm MANUAL items on a device (runbook 16)."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
