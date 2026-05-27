#!/usr/bin/env bash
# =============================================================================
# verify-phase-2.3.sh — Beta & Store-submission metadata checklist.
# Asserts the store-metadata files + launch runbook exist, the Apple keyword
# field is within budget, and — the strict rule — the banned word
# "diagnos(is|e)" never appears in any user-facing storefront copy (the text
# inside <!-- VISIBLE-COPY:START/END --> markers). "diagnosis" IS allowed in the
# Apple keyword field and in the review notes, which sit outside those markers.
# Store approval, the 50-user beta, the >=4.0 rating gate and the legal gate are
# founder actions (MANUAL).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS="$ROOT/docs/store_metadata/ios_app_store.md"
PLAY="$ROOT/docs/store_metadata/google_play.md"
RB="$ROOT/docs/runbooks/19-beta-and-launch.md"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qi "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }

# Extract only the user-facing copy (between VISIBLE-COPY markers) and fail if the
# banned word appears there. Also fails if a file has no markers at all (guards
# against a typo silently making the check vacuous).
no_banned_in_visible() {
  label="$1"; file="$2"
  if [ ! -f "$file" ]; then fail "$label: file missing"; return; fi
  blocks="$(grep -c 'VISIBLE-COPY:START' "$file")"
  if [ "$blocks" -lt 1 ]; then fail "$label: no VISIBLE-COPY blocks found (marker typo?)"; return; fi
  hit="$(awk '/VISIBLE-COPY:START/{f=1;next} /VISIBLE-COPY:END/{f=0;next} f' "$file" | grep -in 'diagnos')"
  if [ -z "$hit" ]; then
    pass "$label: no 'diagnosis/diagnose' in visible copy ($blocks block(s))"
  else
    fail "$label: BANNED word in visible copy -> $hit"
  fi
}

hr; echo "Phase 2.3 — Beta, Store Submission & Public Launch"; hr

# --- Deliverable files present -----------------------------------------------
if [ -f "$IOS" ];  then pass "iOS App Store metadata present";  else fail "iOS metadata missing";  fi
if [ -f "$PLAY" ]; then pass "Google Play metadata present";    else fail "Play metadata missing";  fi
if [ -f "$RB" ];   then pass "Runbook 19 (beta & launch) present"; else fail "Runbook 19 missing"; fi

# --- STRICT RULE: no "diagnosis/diagnose" in any visible store copy ----------
no_banned_in_visible "iOS"  "$IOS"
no_banned_in_visible "Play" "$PLAY"

# --- Required visible copy (title/subtitle/framing) --------------------------
check "iOS: title 'PawDoc: AI Pet Health'"        'PawDoc: AI Pet Health' "$IOS"
check "iOS: subtitle 'Know When to Call the Vet'" 'Know When to Call the Vet' "$IOS"
check "iOS: 'triage' framing present"             'triage' "$IOS"
check "iOS: 'not a substitute' safety framing"    'not a substitute' "$IOS"
check "Play: short/full description framing"      'triage' "$PLAY"
check "Play: 'not a substitute' safety framing"   'not a substitute' "$PLAY"

# --- Apple keyword field: present, <=100 chars, SEO term retained ------------
KW="$(grep -m1 '^symptom,checker' "$IOS" 2>/dev/null)"
if [ -n "$KW" ]; then
  klen=${#KW}
  if [ "$klen" -le 100 ]; then pass "Apple keywords within budget ($klen/100 chars)"; else fail "Apple keywords too long ($klen/100)"; fi
  if printf '%s' "$KW" | grep -qi 'diagnosis'; then pass "Apple keyword SEO term 'diagnosis' retained (allowed in keyword field)"; else fail "Apple keyword 'diagnosis' missing"; fi
else
  fail "Apple keyword line not found (expected line starting 'symptom,checker')"
fi

# --- Play documents it has no hidden keyword field ---------------------------
# (The strict "no banned word in visible copy" rule is already enforced above by
#  no_banned_in_visible; Play's reviewer/compliance notes may reference the word,
#  exactly like the iOS review notes.)
check "Play: documents it has no hidden keyword field" 'no hidden keyword' "$PLAY"

# --- Review notes / framing for App Review -----------------------------------
check "iOS: review notes frame 'information' tool" 'information' "$IOS"
# phrase is hard-wrapped in the prose, so normalize newlines before matching
if tr '\n' ' ' < "$IOS" | grep -qi 'not a veterinary service'; then
  pass "iOS: review notes 'not a veterinary service' framing"
else
  fail "iOS: 'not a veterinary service' framing missing"
fi
check "iOS: in-app account deletion (5.1.1(v)) noted" '5.1.1' "$IOS"
check "iOS: emergencies never paywalled noted" 'never' "$IOS"

# --- Screenshot order documented (slots 1..5) --------------------------------
check "iOS: screenshot 1 caption preserved" 'Know exactly what your pet needs' "$IOS"
check "iOS: screenshot 3 caption preserved" '2am anxiety spirals' "$IOS"
check "iOS: screenshot 4 caption preserved" 'Reviewed by veterinary experts' "$IOS"

# --- Runbook reiterates the HARD legal gate ----------------------------------
check "Runbook 19: references the legal gate (runbook 18)" '18-legal-and-launch-gate' "$RB"
check "Runbook 19: 'HARD GATE' / public release blocked" 'HARD GATE' "$RB"
check "Runbook 19: E&O insurance blocker reiterated" 'E&O' "$RB"
check "Runbook 19: Fastlane 'beta' lane documented" 'fastlane beta' "$RB"
check "Runbook 19: Fastlane 'play_internal' lane documented" 'play_internal' "$RB"
check "Runbook 19: >= 4.0 rating gate documented" '4.0' "$RB"

# --- MANUAL (founder) --------------------------------------------------------
manual "Produce screenshots in the documented order (slots 1-5) for each device size."
manual "Run the 50-user TestFlight beta; collect >= 30 ratings; mean rating must be >= 4.0."
manual "Confirm analysis P95 < 10s on 4G and ZERO open P0 bugs before promoting."
manual "Submit to both stores with the review notes; expect 2-3 Apple review rounds."
manual "DO NOT release to public until runbook 18 §1 is fully green (E&O bound, attorney-reviewed ToS/Privacy live, CR #24 practice-law review, CR #9 retention decision)."

hr
if [ "$fails" -eq 0 ]; then
  echo "Verifiable checks GREEN. Submission may proceed; PUBLIC RELEASE stays gated on the MANUAL legal items."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
