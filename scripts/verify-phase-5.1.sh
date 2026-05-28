#!/usr/bin/env bash
# =============================================================================
# verify-phase-5.1.sh — Exotic Species Expansion (Phase 5.1).
# Structural checks: species grid (+ guinea_pig), species-specific AI guidance,
# and — SAFETY-CRITICAL — species emergency keywords present in BOTH the Python
# safety core and its JS mirror, with the override + paywall-bypass made
# species-aware. Plus the batteries: ruff/pytest, node, flutter analyze/test.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI="$ROOT/ai-service/app"
MJS="$ROOT/supabase/functions/_shared/emergency_keywords.mjs"
M="$ROOT/mobile/lib/src"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }

hr; echo "Phase 5.1 — Exotic Species Expansion"; hr

# --- Safety core: species emergency keywords (Python) ------------------------
check "safety.py: SPECIES_EMERGENCY_KEYWORDS dict"   'SPECIES_EMERGENCY_KEYWORDS' "$AI/safety.py"
check "safety.py: rabbit set"                        '"rabbit":' "$AI/safety.py"
check "safety.py: guinea_pig set"                    '"guinea_pig":' "$AI/safety.py"
check "safety.py: bird set"                          '"bird":' "$AI/safety.py"
check "safety.py: reptile set"                       '"reptile":' "$AI/safety.py"
check "safety.py: override takes species"            'species: str' "$AI/safety.py"
check "safety.py: override checks species keywords"  'SPECIES_EMERGENCY_KEYWORDS.get' "$AI/safety.py"
check "pipeline passes pet.species to override"      'check_emergency_override\(request.text_description, request.pet.species\)' "$AI/pipeline.py"

# --- Safety core: JS mirror (paywall bypass) ---------------------------------
check "JS mirror: SPECIES_EMERGENCY_KEYWORDS"        'SPECIES_EMERGENCY_KEYWORDS' "$MJS"
check "JS mirror: containsEmergencyKeyword(text, species)" 'containsEmergencyKeyword\(text, species\)' "$MJS"
check "Edge passes pet.species (exotic emergencies bypass paywall)" 'containsEmergencyKeyword\(text_description, pet.species\)' "$ROOT/supabase/functions/analyze/index.ts"

# --- Python <-> JS species-key parity (manual sync; both must list all 4) ----
for sp in rabbit guinea_pig bird reptile; do
  if grep -q "$sp" "$AI/safety.py" && grep -q "$sp" "$MJS"; then
    pass "species '$sp' present in BOTH safety.py and the JS mirror"
  else
    fail "species '$sp' missing from one side (lists out of sync)"
  fi
done

# --- AI prompts: species guidance --------------------------------------------
check "prompts.py: SPECIES_GUIDANCE"                 'SPECIES_GUIDANCE' "$AI/prompts.py"
check "prompts.py: species_guidance() injected"      'species_guidance' "$AI/prompts.py"

# --- Flutter species grid ----------------------------------------------------
check "kSpecies includes guinea_pig"                 "'guinea_pig'" "$M/pets/pet.dart"
check "centralized speciesLabel()"                   'String speciesLabel' "$M/pets/pet.dart"
check "guinea pig has an icon/label"                 'Guinea pig' "$M/pets/pet.dart"
check "onboarding grid uses speciesLabel"            'speciesLabel\(s\)' "$M/onboarding/onboarding_flow.dart"
check "pet form uses speciesLabel"                   'speciesLabel\(s\)' "$M/pets/pet_form_screen.dart"

# --- Batteries ---------------------------------------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp51.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp51.log 2>&1); then
    pass "ruff + pytest green"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp51.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions"/_shared/*.test.mjs >/tmp/pawdoc_node51.log 2>&1; then
    pass "node --test (_shared incl. emergency keywords) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node51.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an51.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an51.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt51.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt51.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL ------------------------------------------------------------------
manual "Keywords are ENGLISH-ONLY (strict rule); localization is Phase 5.4 (CR #11)."
manual "On device: create a rabbit/guinea pig/bird/reptile end-to-end; confirm a species emergency (e.g. rabbit 'not eating') jumps straight to EMERGENCY."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 5.1 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
