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

# Extract only the user-facing copy (between VISIBLE-COPY markers) and fail if a
# diagnosis is CLAIMED there. Also fails if a file has no markers at all (guards
# against a typo silently making the check vacuous).
#
# The scan used to be a bare `grep -i diagnos`, and it had been RED since the
# store copy was cleaned up — because a substring scan cannot tell a denial from
# an assertion. It was failing on the two sentences that exist precisely to
# disclaim diagnosis:
#
#   "…how soon to call — never a verdict, never a diagnosis."
#   "It does not diagnose, does not provide veterinary medical advice…"
#
# That is not a near-miss; it is backwards. Google Play's Health Content &
# Services policy expects an app that is not a regulated medical device to state
# in its description that it "does not diagnose, treat, cure, or prevent any
# medical condition" — so the old rule forbade the exact wording the policy
# requires, and a red gate nobody can satisfy is a gate nobody runs.
#
# So: strip the negated forms first, then scan what is left. An assertion still
# fails; a denial passes. `selfcheck_banned_scan` below proves both directions.
strip_negated_diagnosis() {
  # Handles: "never a diagnosis", "not a diagnosis", "no diagnosis",
  # "does not diagnose", "doesn't diagnose", "cannot diagnose",
  # "is not a diagnostic tool", "never diagnoses".
  sed -E -e 's/(never|not|no|cannot|can.t|won.t|will not|do(es)? not|do(es)?n.t)([[:space:]]+(a|an|any|the|provide|offer|give|make|attempt[[:space:]]+to|claim[[:space:]]+to|substitute[[:space:]]+for))*[[:space:]]+diagnos[a-z]*/[NEGATED]/gI'
}

no_banned_in_visible() {
  label="$1"; file="$2"
  if [ ! -f "$file" ]; then fail "$label: file missing"; return; fi
  blocks="$(grep -c 'VISIBLE-COPY:START' "$file")"
  if [ "$blocks" -lt 1 ]; then fail "$label: no VISIBLE-COPY blocks found (marker typo?)"; return; fi
  hit="$(awk '/VISIBLE-COPY:START/{f=1;next} /VISIBLE-COPY:END/{f=0;next} f' "$file" \
          | strip_negated_diagnosis | grep -in 'diagnos')"
  if [ -z "$hit" ]; then
    pass "$label: no CLAIMED diagnosis in visible copy ($blocks block(s); denials allowed)"
  else
    fail "$label: BANNED claim in visible copy -> $hit"
  fi
}

# Proves the scan still bites. A rule that only ever passes is not a rule, and
# this one was just loosened — so it is tested in both directions, here, on
# every run.
selfcheck_banned_scan() {
  claim="PawDoc will diagnose your pet in seconds."
  denial="PawDoc does not diagnose, and never a diagnosis."
  claim_left="$(printf '%s' "$claim"  | strip_negated_diagnosis | grep -ic 'diagnos')"
  denial_left="$(printf '%s' "$denial" | strip_negated_diagnosis | grep -ic 'diagnos')"
  if [ "$claim_left" -ge 1 ] && [ "$denial_left" -eq 0 ]; then
    pass "self-check: the scan catches a diagnosis CLAIM and allows a DENIAL"
  else
    fail "self-check: scan is broken (claim_left=$claim_left denial_left=$denial_left)"
  fi
}

hr; echo "Phase 2.3 — Beta, Store Submission & Public Launch"; hr

# --- Deliverable files present -----------------------------------------------
if [ -f "$IOS" ];  then pass "iOS App Store metadata present";  else fail "iOS metadata missing";  fi
if [ -f "$PLAY" ]; then pass "Google Play metadata present";    else fail "Play metadata missing";  fi
if [ -f "$RB" ];   then pass "Runbook 19 (beta & launch) present"; else fail "Runbook 19 missing"; fi

# --- STRICT RULE: a diagnosis is never CLAIMED in visible store copy ---------
selfcheck_banned_scan
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
# The keyword set was rewritten so it "matches what the app actually is", which
# moved `symptom,checker` off the start of the line — and this check, which
# anchored on `^symptom,checker`, had been failing ever since. Match the line by
# a term it contains rather than by the term it happens to begin with.
KW="$(grep -m1 -E '^[a-z]+(,[a-z]+)*$' "$IOS" 2>/dev/null | grep -m1 'symptom' 2>/dev/null)"
if [ -z "$KW" ]; then
  KW="$(grep -m1 'symptom,checker' "$IOS" 2>/dev/null)"
fi
if [ -n "$KW" ]; then
  klen=${#KW}
  if [ "$klen" -le 100 ]; then pass "Apple keywords within budget ($klen/100 chars)"; else fail "Apple keywords too long ($klen/100)"; fi
  # Inverted, and deliberately so. This used to assert that `diagnosis` was
  # RETAINED in the keyword field as an SEO term. Evolution decision I4 removed
  # it — "bidding on the one word the entire product posture disclaims was a
  # store risk and a litigation exhibit" — and the check has been red ever
  # since, demanding the term back. The rule now enforces the decision.
  if printf '%s' "$KW" | grep -qiE 'diagnos|cure|treat|prevent'; then
    fail "Apple keyword field bids on a capability the product disclaims -> $KW"
  else
    pass "Apple keyword field claims no diagnosis/treatment (decision I4 held)"
  fi
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
# These three checks pinned the ORIGINAL captions, and all three had been red
# since the store copy was corrected. Two of the three were pinning copy that
# was removed on purpose:
#
#   "Know exactly what your pet needs"  — a certainty claim
#   "End 2am anxiety spirals"           — an outcome promise
#   "Reviewed by veterinary experts"    — false: no veterinarian reviews anything
#
# The third is the serious one. A verifier that FAILS THE BUILD unless the
# listing claims veterinary review is not a safety gate; it is the defect,
# wearing the gate's clothes. So the assertion is inverted: the phrase must be
# ABSENT, and the slot structure is what gets checked instead.
if [ "$(grep -c '^[1-5]\. ' "$IOS")" -ge 5 ]; then
  pass "iOS: five ordered screenshot slots documented"
else
  fail "iOS: the five ordered screenshot slots are missing"
fi
check "iOS: slot 3 keeps the 'never says fine' framing" 'never says fine' "$IOS"
check "iOS: slot 4 keeps 'always free' emergency framing" 'always free' "$IOS"
# The inverted assertion — these must NOT come back, in either listing.
for banned_claim in 'Reviewed by veterinary experts' 'vet-approved' 'Know exactly what'; do
  if grep -qiF "$banned_claim" "$IOS" "$PLAY"; then
    fail "store copy re-introduced a banned claim: '$banned_claim'"
  else
    pass "store copy free of '$banned_claim'"
  fi
done

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
