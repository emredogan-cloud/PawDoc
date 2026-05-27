#!/usr/bin/env bash
# =============================================================================
# verify-phase-3.4.sh — Local Vet Finder & Health Export (Phase 3.4).
# Structural checks (key-hiding Places proxy, nearest-5, graceful fallback,
# report export, analytics) + the security assertion that NO Places/Maps API
# key is present in the Flutter client, plus the real batteries: node --test,
# ruff/pytest, flutter analyze/test. Live Places + device location are MANUAL.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FN="$ROOT/supabase/functions"
M="$ROOT/mobile/lib/src"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 3.4 — Local Vet Finder & Health Export"; hr

# --- Files present -----------------------------------------------------------
have "$FN/find-vets/index.ts"               "/find-vets Edge Function"
have "$FN/_shared/places.mjs"               "Places proxy helpers"
have "$M/vet_finder/vet_finder_screen.dart" "Vet finder screen"
have "$M/vet_finder/vet_finder_service.dart" "Vet finder service"
have "$M/vet_finder/maps_links.dart"        "Maps/dialer deep links (fallback)"
have "$M/export/health_report.dart"         "Health report builder"
have "$M/export/health_report_service.dart" "Health report service"

# --- Places proxy: key-hiding + nearest 5 ------------------------------------
check "Edge holds PLACES_API_KEY (server-side)" 'Deno.env.get\("PLACES_API_KEY"\)' "$FN/find-vets/index.ts"
check "Edge sends the key as X-Goog-Api-Key"    'X-Goog-Api-Key' "$FN/find-vets/index.ts"
check "Edge fails safe (empty vets on error)"   'vet_finder_unavailable' "$FN/find-vets/index.ts"
check "Proxy returns nearest 5"                 'slice\(0, 5\)' "$FN/_shared/places.mjs"
check "Proxy supports nearby + text (zip/city)" 'places:searchText' "$FN/_shared/places.mjs"
check "find-vets requires a JWT"                '\[functions.find-vets\]' "$ROOT/supabase/config.toml"

# --- CRITICAL: no Places/Maps API key in the Flutter client ------------------
if grep -rIlnE 'X-Goog-Api-Key|PLACES_API_KEY|AIza[0-9A-Za-z_-]{10}|maps\.googleapis\.com/maps/api' "$ROOT/mobile/lib" >/dev/null 2>&1; then
  fail "API KEY LEAK: a Places/Maps key or keyed endpoint appears in mobile/lib"
else
  pass "No Places/Maps API key or keyed endpoint in the Flutter client"
fi

# --- Graceful fallback (permission denial) -----------------------------------
check "Handles permission denied/deniedForever" 'LocationPermission.deniedForever' "$M/vet_finder/vet_finder_screen.dart"
check "Manual zip/city fallback input"          'vet_manual_query' "$M/vet_finder/vet_finder_screen.dart"
check "Always offers an Open-Maps fallback"     'vet_open_maps' "$M/vet_finder/vet_finder_screen.dart"
check "Maps deep link (no key) for fallback"    'www.google.com/maps' "$M/vet_finder/maps_links.dart"

# --- Triggered from EMERGENCY + MONITOR results ------------------------------
check "EMERGENCY screen opens the vet finder"   'VetFinderScreen\(emergency: true\)' "$M/analysis/emergency_result_screen.dart"
check "MONITOR result offers the vet finder"    'result_find_vet' "$M/analysis/result_screen.dart"

# --- Health report export ----------------------------------------------------
check "Report builder is pure + structured"     'buildHealthReport' "$M/export/health_report.dart"
check "Report carries the not-a-diagnosis note" 'AI-assisted information from PawDoc' "$M/export/health_report.dart"
check "Export action on the history screen"     'export_health_report' "$M/health/history_timeline_screen.dart"

# --- Analytics ---------------------------------------------------------------
check "Analytics: vet_finder_opened"  'vet_finder_opened' "$M/analytics/analytics.dart"
check "Analytics: vet_called"         'vet_called' "$M/analytics/analytics.dart"
check "Analytics: health_report_exported" 'health_report_exported' "$M/analytics/analytics.dart"

# --- node --test -------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
  if node --test "$FN"/_shared/*.test.mjs >/tmp/pawdoc_node34.log 2>&1; then
    pass "node --test (_shared) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node34.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

# --- AI service (unaffected; run for safety) ---------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp34.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp34.log 2>&1); then
    pass "ruff + pytest green"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp34.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

# --- Flutter -----------------------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an34.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an34.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt34.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt34.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL (founder / live infra / device) ----------------------------------
manual "Set PLACES_API_KEY on find-vets (supabase secrets); restrict it + add a billing alert (CR #12)."
manual "On device: grant location -> nearest vets list with working Call + Directions."
manual "On device: deny location -> manual zip/city search + Open Maps fallback (no crash)."
manual "Export a health report from the history screen -> share sheet shows pet + triage + events."
manual "Deno typecheck of find-vets (supabase CI) — deno not run here."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 3.4 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
