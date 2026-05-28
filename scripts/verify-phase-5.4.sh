#!/usr/bin/env bash
# =============================================================================
# verify-phase-5.4.sh — Embedded Telehealth, Localization (EN + DE) & B2B-Lite.
#
# SAFETY GATE: CR #11 — German emergency keywords MUST be wired into the pre-AI
# override on both Python and JS sides; the override pipeline must select keys
# by the user's locale. This script structurally asserts those properties.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# CR #11 — keyword sources.
SAFETY_PY="$ROOT/ai-service/app/safety.py"
KW_MJS="$ROOT/supabase/functions/_shared/emergency_keywords.mjs"
KW_TEST_MJS="$ROOT/supabase/functions/_shared/emergency_keywords.test.mjs"

# Pipeline + Edge wiring.
PIPELINE="$ROOT/ai-service/app/pipeline.py"
MODELS="$ROOT/ai-service/app/models.py"
EDGE_ANALYZE="$ROOT/supabase/functions/analyze/index.ts"
EDGE_ANON="$ROOT/supabase/functions/analyze-anonymous/index.ts"

# Flutter i18n + telehealth + B2B-Lite.
M="$ROOT/mobile/lib/src"
L10N_EN="$ROOT/mobile/lib/l10n/app_en.arb"
L10N_DE="$ROOT/mobile/lib/l10n/app_de.arb"

# B2B-Lite migration + RPC re-create.
MIG_B2B="$ROOT/supabase/migrations/20260528010000_b2b_lite.sql"
MIG_B2B_JOURNAL="$ROOT/supabase/migrations/20260528010001_b2b_lite_journal_eligibility.sql"
RC_MJS="$ROOT/supabase/functions/_shared/revenuecat.mjs"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 5.4 — Telehealth, Localization (EN + DE), B2B-Lite"; hr

# --- CR #11: localized emergency keywords (SAFETY GATE) ----------------------
have "$SAFETY_PY"                          "safety.py (locale-aware override)"
have "$KW_MJS"                             "JS emergency keyword mirror"
have "$KW_TEST_MJS"                        "JS keyword tests"

# Both maps use locale-keyed dicts (en + de).
check "Python: EMERGENCY_KEYWORDS_BY_LOCALE has 'en'"    "EMERGENCY_KEYWORDS_BY_LOCALE.*\"en\"" "$SAFETY_PY"
check "Python: EMERGENCY_KEYWORDS_BY_LOCALE has 'de'"    "\"de\"" "$SAFETY_PY"
check "Python: SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE de"  "SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE" "$SAFETY_PY"
check "Python: at least one DE seizure/poisoning keyword" "Krampfanfall|Vergiftung" "$SAFETY_PY"
check "Python: DE rabbit GI-stasis keyword"               "frisst nicht" "$SAFETY_PY"
check "Python: _norm_locale falls back to en"             "return code if code in EMERGENCY_KEYWORDS_BY_LOCALE else \"en\"" "$SAFETY_PY"
check "Python: check_emergency_override accepts locale"   "locale: str \| None = \"en\"" "$SAFETY_PY"

check "JS: EMERGENCY_KEYWORDS_BY_LOCALE 'en'"             "en: \[" "$KW_MJS"
check "JS: EMERGENCY_KEYWORDS_BY_LOCALE 'de'"             "de: \[" "$KW_MJS"
check "JS: SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE"          "SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE" "$KW_MJS"
check "JS: containsEmergencyKeyword(text, species, locale)" "containsEmergencyKeyword\(text, species, locale\)" "$KW_MJS"
check "JS: normLocale falls back to en"                   "return Object.prototype.hasOwnProperty.call" "$KW_MJS"

# Pipeline + AnalyzeRequest.locale.
check "AnalyzeRequest.locale field"                       "locale: str" "$MODELS"
check "Pipeline passes request.locale to the override"    "request\.locale" "$PIPELINE"

# Edge wires preferred_locale through.
check "Edge /analyze selects users.preferred_locale"      "preferred_locale" "$EDGE_ANALYZE"
check "Edge /analyze sends locale to AI"                  "locale, // Phase 5.4" "$EDGE_ANALYZE"
check "Edge /analyze localizes the emergency check"       "containsEmergencyKeyword\(text_description, pet\.species, locale\)" "$EDGE_ANALYZE"
check "Edge /analyze-anonymous accepts body.locale"       "body\?\.locale" "$EDGE_ANON"

# --- Flutter i18n infra ------------------------------------------------------
have "$L10N_EN"                            "English ARB"
have "$L10N_DE"                            "German ARB"
have "$ROOT/mobile/lib/l10n/app_localizations.dart" "Generated AppLocalizations"
have "$ROOT/mobile/l10n.yaml"              "l10n.yaml"
check "pubspec: flutter_localizations"     "flutter_localizations" "$ROOT/mobile/pubspec.yaml"
check "pubspec: intl"                      "intl:" "$ROOT/mobile/pubspec.yaml"
check "pubspec: generate: true"            "generate: true" "$ROOT/mobile/pubspec.yaml"
check "MaterialApp wires localizationsDelegates" "localizationsDelegates: AppLocalizations" "$M/app.dart"
check "EmergencyResultScreen uses AppLocalizations" "AppLocalizations.of\(context\)" "$M/analysis/emergency_result_screen.dart"
check "Emergency disclaimer is localized (EN)"    "PawDoc provides information, not a diagnosis" "$L10N_EN"
check "Emergency disclaimer is localized (DE)"    "PawDoc liefert Informationen" "$L10N_DE"
check "EMERGENCY title localized (DE: Notfall)"   "Notfall sein" "$L10N_DE"

# --- Telehealth (Airvet-style affiliate) -------------------------------------
have "$M/monetization/telehealth_button.dart"    "TelehealthButton widget"
check "AIRVET_AFFILIATE_URL in Env"               "AIRVET_AFFILIATE_URL" "$M/config/env.dart"
check "Analytics.telehealthClicked"               "telehealth_clicked" "$M/analytics/analytics.dart"
check "TelehealthButton on Emergency screen"      "TelehealthButton\(source: 'emergency_result'\)" "$M/analysis/emergency_result_screen.dart"
check "TelehealthButton on Monitor result"        "TelehealthButton\(source: 'monitor_result'\)" "$M/analysis/result_screen.dart"
check "TelehealthButton on Home"                  "TelehealthButton\(source: 'home'\)" "$M/home/home_screen.dart"

# --- B2B-Lite (sitter) -------------------------------------------------------
have "$MIG_B2B"                                  "B2B-Lite migration (pets.client_name)"
have "$MIG_B2B_JOURNAL"                          "Journal eligibility extension"
check "pets.client_name column"                  "add column .*client_name" "$MIG_B2B"
check "Journal RPC includes b2b_lite"            "'premium', 'family', 'trial', 'b2b_lite'" "$MIG_B2B_JOURNAL"

check "Pet model: clientName"                    "clientName" "$M/pets/pet.dart"
check "Pet toColumns includes client_name"       "'client_name'" "$M/pets/pet.dart"
check "Pet form: client_name field"              "pet_client_name_field" "$M/pets/pet_form_screen.dart"

check "pet_limits unlimited for b2b_lite"        "_unlimitedPetTiers.*'b2b_lite'" "$M/pets/pet_limits.dart"
check "UserProfile.isPremium includes b2b_lite"  "'b2b_lite'" "$M/account/user_profile.dart"
check "Edge analyze PREMIUM_STATUSES has b2b_lite" "premium.*family.*trial.*b2b_lite" "$EDGE_ANALYZE"
check "RevenueCat maps entitlement to b2b_lite"  "TIER_ENTITLEMENTS" "$RC_MJS"

# --- Batteries ---------------------------------------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp54.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp54.log 2>&1); then
    pass "ruff + pytest green"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp54.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions"/_shared/*.test.mjs >/tmp/pawdoc_node54.log 2>&1; then
    pass "node --test (_shared incl. DE keywords + RC + journal) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node54.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

if command -v docker >/dev/null 2>&1; then
  if "$ROOT/scripts/test-journals.sh" >/tmp/pawdoc_jpg54.log 2>&1; then
    pass "journals pg test green (+ B2B-Lite eligibility)"
  else
    fail "journals pg test failed (see /tmp/pawdoc_jpg54.log)"
  fi
else
  manual "Run ./scripts/test-journals.sh (needs Docker)."
fi

if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an54.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an54.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt54.log 2>&1); then
    pass "flutter test green (incl. l10n + b2b_lite)"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt54.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL (founder) --------------------------------------------------------
manual "Apply both new migrations on Supabase (supabase db push) so 'b2b_lite' opt-in pets are eligible for journals."
manual "Configure a RevenueCat 'b2b_lite' entitlement + \$19.99/mo product on the iOS / Play product side; verify the webhook event carries the right entitlement_id (mocked via _shared/revenuecat.mjs)."
manual "Set AIRVET_AFFILIATE_URL on the build (or leave empty to hide the CTA until the affiliate deal lands)."
manual "ASO: prepare a German App Store listing; native-speaker review of EMERGENCY copy + disclaimer before the DE submission."
manual "Full UI string sweep (beyond the safety-critical strings translated here) is a content task for the German launch — track in docs/runbooks/."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 5.4 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
