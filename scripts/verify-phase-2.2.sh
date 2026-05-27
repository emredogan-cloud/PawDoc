#!/usr/bin/env bash
# =============================================================================
# verify-phase-2.2.sh — Legal, Compliance & Trust Gate checklist.
# Asserts the legal templates + launch runbook exist with the required clauses,
# and runs the disclaimer-source verification. Insurance / attorney review /
# support email are founder actions (MANUAL).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOS="$ROOT/docs/legal/terms-of-service.md"
PRIV="$ROOT/docs/legal/privacy-policy.md"
RB="$ROOT/docs/runbooks/18-legal-and-launch-gate.md"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qi "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }

hr; echo "Phase 2.2 — Legal, Compliance & Trust Gate"; hr

# --- Legal templates present + key clauses -----------------------------------
if [ -f "$TOS" ]; then pass "Terms of Service template present"; else fail "ToS template missing"; fi
if [ -f "$PRIV" ]; then pass "Privacy Policy template present"; else fail "Privacy Policy template missing"; fi
check "ToS: attorney-review disclaimer present" 'NOT LEGAL ADVICE' "$TOS"
check "ToS: 'information/guidance, not veterinary diagnosis' framing" 'not.*veterinary diagnosis' "$TOS"
check "ToS: emergency -> contact a vet" 'emergency' "$TOS"
check "ToS: in-app account deletion referenced" 'delete your account' "$TOS"
check "Privacy: attorney-review disclaimer present" 'NOT LEGAL ADVICE' "$PRIV"
check "Privacy: GDPR legal bases" 'legal bases' "$PRIV"
check "Privacy: EU data residency" 'EU region' "$PRIV"
check "Privacy: CR #9 retention decision flagged" 'DECISION REQUIRED' "$PRIV"
check "Privacy: in-app deletion / erasure right" 'delete your account' "$PRIV"

# --- Launch/legal runbook (the hard gate) ------------------------------------
if [ -f "$RB" ]; then pass "Runbook 18 present"; else fail "Runbook 18 missing"; fi
check "Runbook: E&O insurance >= \$100K blocker" 'E&O' "$RB"
check "Runbook: CR #24 vet practice-law review" 'practice-law' "$RB"
check "Runbook: support@pawdoc.app stand-up" 'support@pawdoc.app' "$RB"
check "Runbook: App Store notes avoid 'diagnosis'" 'DO NOT use the word' "$RB"

# --- Disclaimer source (API-injected) ----------------------------------------
if "$ROOT/scripts/verify-disclaimers.sh" >/tmp/pawdoc_disc.log 2>&1; then
  pass "disclaimers are API-injected (verify-disclaimers.sh green)"
else
  fail "disclaimer verification failed (see /tmp/pawdoc_disc.log)"
fi

# --- MANUAL (founder / legal) ------------------------------------------------
manual "Bind E&O insurance (>= \$100K) BEFORE launch; keep the certificate on file."
manual "Have a licensed attorney finalize the ToS + Privacy Policy (fill all [BRACKETS])."
manual "Complete the veterinary practice-law review per launch jurisdiction (CR #24)."
manual "Decide the CR #9 retention policy and reconcile Privacy Policy §6 with the code."

hr
if [ "$fails" -eq 0 ]; then
  echo "Verifiable checks GREEN. The launch gate stays CLOSED until the MANUAL items are done."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
