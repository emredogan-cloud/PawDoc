#!/usr/bin/env bash
# =============================================================================
# verify-phase-3.1.sh — Health History & Multi-Pet Foundation checklist.
# Structural checks for the timeline, manual health events, multi-pet switcher +
# tier gate, breed insight cards, and analytics. Proves the health_events RLS
# INSERT path with the RLS harness (Docker) and runs the Flutter analyzer/tests
# when the toolchain is present; device UX (reactive switching) stays MANUAL.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
M="$ROOT/mobile/lib/src"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qi "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 3.1 — Health History & Multi-Pet Foundation"; hr

# --- Deliverable files present -----------------------------------------------
have "$M/health/timeline.dart"                 "Timeline model + provider"
have "$M/health/history_timeline_screen.dart"  "Health history screen"
have "$M/health/health_event.dart"             "HealthEvent model"
have "$M/health/health_events_repository.dart" "HealthEvents repository"
have "$M/health/health_event_form_screen.dart" "Manual event quick-add form"
have "$M/health/breed_insights.dart"           "Breed insight data"
have "$M/health/breed_insight_card.dart"       "Breed insight card widget"
have "$M/pets/active_pet.dart"                 "Active-pet state (switcher)"
have "$M/pets/pet_limits.dart"                 "Tier-limit pure logic"
have "$M/pets/add_pet_flow.dart"               "Gated add-pet flow"
have "$ROOT/mobile/test/health_test.dart"      "Phase 3.1 unit tests"

# --- Timeline interleaves analyses + manual events ---------------------------
check "Timeline merges analyses + health_events" 'static List<TimelineItem> merge' "$M/health/timeline.dart"
check "Timeline reads both tables"               'health_events' "$M/health/timeline.dart"

# --- Multi-pet switcher + reactive active pet --------------------------------
check "Active-pet provider (reactive switching)" 'activePetProvider' "$M/pets/active_pet.dart"
check "Home wires the pet switcher"              'pet_switcher' "$M/home/home_screen.dart"
check "Home shows the breed insight card"        'BreedInsightCard' "$M/home/home_screen.dart"

# --- Tier limits: Free/Premium = 2, Family = unlimited -----------------------
check "petLimitFor: Family is unlimited (null)"  "subscriptionStatus == 'family' ? null : 2" "$M/pets/pet_limits.dart"
check "canAddPet enforces the cap"               'bool canAddPet' "$M/pets/pet_limits.dart"
check "Add-pet flow enforces the tier limit"     'canAddPet' "$M/pets/add_pet_flow.dart"
check "Pets list routes through the gated flow"  'startAddPetFlow' "$M/pets/pets_list_screen.dart"

# --- Analytics ---------------------------------------------------------------
check "Analytics: health_event_logged" 'health_event_logged' "$M/analytics/analytics.dart"
check "Analytics: multi_pet_added"     'multi_pet_added' "$M/analytics/analytics.dart"

# --- Routing -----------------------------------------------------------------
check "Router exposes /history" "'/history'" "$M/router/app_router.dart"

# --- CR #2: health_events RLS INSERT positive control present ----------------
check "RLS test has health_events own-pet INSERT control" 'Rabies booster' "$ROOT/supabase/tests/rls_isolation.sql"

# --- Live RLS proof (Docker) -------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  if "$ROOT/scripts/test-rls.sh" >/tmp/pawdoc_rls31.log 2>&1; then
    pass "RLS harness green — health_events inserts succeed, cross-user blocked (CR #2)"
  else
    fail "RLS harness failed (see /tmp/pawdoc_rls31.log)"
  fi
else
  manual "Run ./scripts/test-rls.sh (needs Docker) to prove health_events inserts."
fi

# --- Flutter analyze + tests -------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_analyze31.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze reported issues (see /tmp/pawdoc_analyze31.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_test31.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_test31.log)"
  fi
else
  manual "Run 'flutter analyze' and 'flutter test' from mobile/ (Flutter not on PATH here)."
fi

# --- MANUAL (device) ---------------------------------------------------------
manual "On device: switch the active pet and confirm the breed card, Check target, and history all update."
manual "On device: log a manual event and confirm it appears immediately in the timeline."
manual "On device: as a non-Family user with 2 pets, confirm 'Add pet' shows the upgrade prompt."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 3.1 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
