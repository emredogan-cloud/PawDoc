#!/usr/bin/env bash
# =============================================================================
# verify-phase-4.2.sh — Onboarding & Paywall Experiments (Phase 4.2).
# Structural checks: variants wired to PostHog flags, fail-safe to Variant A,
# and — SACRED — the EMERGENCY trust rule is untouched (the emergency screen
# never references a paywall, and the paywall policy still blocks on emergency).
# Plus the real batteries: node, ruff/pytest, flutter analyze/test.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
M="$ROOT/mobile/lib/src"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 4.2 — Onboarding & Paywall Experiments"; hr

# --- Files -------------------------------------------------------------------
have "$M/experiments/feature_flags.dart"      "Feature flags (getVariant)"
have "$M/monetization/paywall_copy.dart"      "Paywall social-proof copy (CMS-swappable)"
have "$M/monetization/paywall_screen.dart"    "Paywall screen (A/B/C)"
have "$M/onboarding/onboarding_flow.dart"     "Onboarding flow (Variant B)"

# --- Flags: keys + fail-safe to A --------------------------------------------
check "getVariant exists"                     'Future<String> getVariant' "$M/experiments/feature_flags.dart"
check "getVariant defaults to control A"      "defaultValue = 'A'" "$M/experiments/feature_flags.dart"
check "Flag key: onboarding_variant"          "onboardingVariant = 'onboarding_variant'" "$M/experiments/feature_flags.dart"
check "Flag key: paywall_variant"             "paywallVariant = 'paywall_variant'" "$M/experiments/feature_flags.dart"

# --- Paywall variants A/B/C --------------------------------------------------
check "Paywall reads paywall_variant"         'FeatureFlagKeys.paywallVariant' "$M/monetization/paywall_screen.dart"
check "Variant B: monthly featured"           "featured: _variant == 'B'" "$M/monetization/paywall_screen.dart"
check "Variant B: annual 'Best value' badge"  "Best value" "$M/monetization/paywall_screen.dart"
check "Variant C: social proof block"         'paywall_social_proof' "$M/monetization/paywall_screen.dart"
check "Testimonial copy is CMS-swappable"     'PaywallSocialProof' "$M/monetization/paywall_copy.dart"

# --- Onboarding Variant B ----------------------------------------------------
check "Onboarding reads onboarding_variant"   'FeatureFlagKeys.onboardingVariant' "$M/onboarding/onboarding_flow.dart"
check "Variant B shows paywall after pet setup" '_maybeShowOnboardingPaywall' "$M/onboarding/onboarding_flow.dart"
check "Variant B is skippable (pushes PaywallScreen)" 'PaywallScreen' "$M/onboarding/onboarding_flow.dart"

# --- SACRED: EMERGENCY trust rule untouched ----------------------------------
check "paywall policy still blocks on EMERGENCY" 'c.lastTriageWasEmergency\) return false' "$M/monetization/paywall_policy.dart"
if grep -qiE 'maybeShowPaywall|PaywallScreen' "$M/analysis/emergency_result_screen.dart"; then
  fail "EMERGENCY screen references a paywall (it MUST NEVER)"
else
  pass "EMERGENCY screen has NO paywall reference (never paywalled)"
fi
check "Emergency rule asserted as variant-independent (test)" 'variant-independent' "$ROOT/mobile/test/paywall_policy_test.dart"
check "maybe_show_paywall still gates on the policy" 'shouldShowPaywall' "$M/monetization/maybe_show_paywall.dart"

# --- Analytics ---------------------------------------------------------------
check "paywall_shown carries the variant"     "capture\('paywall_shown'" "$M/analytics/analytics.dart"
check "onboarding_paywall_shown event"        'onboarding_paywall_shown' "$M/analytics/analytics.dart"

# --- Batteries ---------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions"/_shared/*.test.mjs >/tmp/pawdoc_node42.log 2>&1; then
    pass "node --test (_shared) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node42.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp42.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp42.log 2>&1); then
    pass "ruff + pytest green"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp42.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an42.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an42.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt42.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt42.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL ------------------------------------------------------------------
manual "PostHog: create multivariate flags 'onboarding_variant' (A,B) and 'paywall_variant' (A,B,C); roll out % per variant."
manual "Enforce the sample gate: >= 500 users/variant before calling a winner; keep annual-first (A) as control."
manual "On device: each variant renders; an EMERGENCY result still shows NO paywall under every variant."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 4.2 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
