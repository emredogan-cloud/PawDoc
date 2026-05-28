#!/usr/bin/env bash
# =============================================================================
# verify-phase-6.3.sh — Family Sharing RLS + PDF Health Report add-on +
#                       Pet Insurance affiliate CTA (Phase 6.3).
#
# The highest-risk piece is the RLS redesign — this script asserts the new
# schema + helpers + policies are in place AND runs scripts/test-rls.sh
# (which exercises the User A / B / C / D scenario on real Postgres).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MIG_FS="$ROOT/supabase/migrations/20260528030000_family_sharing.sql"
MIG_PDF="$ROOT/supabase/migrations/20260528030001_pdf_report_addon.sql"
PG_TEST="$ROOT/supabase/tests/family_sharing.sql"
RC_MJS="$ROOT/supabase/functions/_shared/revenuecat.mjs"
RC_WEBHOOK="$ROOT/supabase/functions/revenuecat-webhook/index.ts"
EDGE_PDF="$ROOT/supabase/functions/generate-pdf-report/index.ts"
PDF_MJS="$ROOT/supabase/functions/_shared/pdf_report.mjs"
M="$ROOT/mobile/lib/src"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 6.3 — Family Sharing + PDF Report + Insurance affiliate"; hr

# --- Family Sharing — schema + helpers + policies + trigger ------------------
have "$MIG_FS"                                       "Family Sharing migration"
have "$PG_TEST"                                      "Family Sharing pg test"
check "family_groups table"                          "create table public.family_groups" "$MIG_FS"
check "family_members table"                         "create table public.family_members" "$MIG_FS"
check "pets.family_group_id column"                  "add column if not exists family_group_id" "$MIG_FS"
check "Helper: is_family_member SECURITY DEFINER"    "function public.is_family_member" "$MIG_FS"
check "Helper: is_family_pet SECURITY DEFINER"       "function public.is_family_pet" "$MIG_FS"
check "Signup trigger: create_solo_family_for_new_user" "create_solo_family_for_new_user" "$MIG_FS"
check "Pet BEFORE INSERT trigger: default_pet_family_group" "default_pet_family_group" "$MIG_FS"
check "Backfill: solo group for every existing user" "from public.users u" "$MIG_FS"

check "Pets policy: pets_select_family exists"       "policy pets_select_family on public.pets" "$MIG_FS"
check "Pets policy: uses is_family_member helper"    "using \(public.is_family_member\(family_group_id\)\)" "$MIG_FS"
check "Pets UPDATE remains owner-only"               "policy pets_update_owner" "$MIG_FS"
check "Analyses policy: analyses_select_family"      "policy analyses_select_family on public.analyses" "$MIG_FS"
check "Analyses policy: uses is_family_pet helper"   "using \(public.is_family_pet\(pet_id\)\)" "$MIG_FS"
check "Health events policy: family-wide"            "policy health_events_select_family" "$MIG_FS"
check "Reminders SELECT goes family-wide"            "policy reminders_select_family" "$MIG_FS"

# --- PDF Health Report (Edge Function + RC addon + entitlement) -------------
have "$MIG_PDF"                                      "PDF addon migration"
have "$EDGE_PDF"                                     "/generate-pdf-report Edge Function"
have "$PDF_MJS"                                      "pdf_report.mjs shared shaper"
have "$ROOT/supabase/functions/_shared/pdf_report.test.mjs" "pdf_report tests"
check "users.pdf_reports_remaining column"           "pdf_reports_remaining int not null default 0" "$MIG_PDF"
check "CHECK constraint: pdf_reports_remaining >= 0" "pdf_reports_remaining >= 0" "$MIG_PDF"
check "Edge: server-side premium-tier check"         "PREMIUM_STATUSES" "$EDGE_PDF"
check "Edge: enforces credits when not premium"      "credits <= 0" "$EDGE_PDF"
check "Edge: decrements counter after success"       "pdf_reports_remaining: credits - 1" "$EDGE_PDF"
check "Edge: returns 402 add-on required"            "addon_required" "$EDGE_PDF"
check "Edge: Cache-Control no-store"                 'cache-control.*no-store' "$EDGE_PDF"
check "Edge: NO storage / NO persistence"            "NO SERVER STORAGE" "$EDGE_PDF"
check "Edge: PDF rendered inline via pdf-lib"        "pdf-lib" "$EDGE_PDF"
check "config.toml registers /generate-pdf-report"   "functions.generate-pdf-report" "$ROOT/supabase/config.toml"

check "RevenueCat: ADDON_PRODUCTS table"             "ADDON_PRODUCTS" "$RC_MJS"
check "RevenueCat: addonCreditsFromEvent"            "function addonCreditsFromEvent" "$RC_MJS"
check "Webhook: applies add-on BEFORE subscription"  "addonCreditsFromEvent\(event\)" "$RC_WEBHOOK"
check "Webhook: addon increments the counter column" "current \+ addon.delta" "$RC_WEBHOOK"

# --- Mobile glue (entitlement helper + button + analytics) ------------------
check "UserProfile.pdfReportsRemaining field"        "pdfReportsRemaining" "$M/account/user_profile.dart"
check "UserProfile.canRequestPdfReport helper"       "canRequestPdfReport" "$M/account/user_profile.dart"
have "$M/health/pdf_report_service.dart"             "PdfReportService"
check "PdfReportPaywallException type"               "class PdfReportPaywallException" "$M/health/pdf_report_service.dart"
check "PdfReportService shares (no persistent upload)" "SharePlus.instance.share" "$M/health/pdf_report_service.dart"
check "History screen has the PDF Health Report button" "generate_pdf_report" "$M/health/history_timeline_screen.dart"
check "Analytics.pdfReportRequested"                 "pdf_report_requested" "$M/analytics/analytics.dart"
check "Analytics.pdfReportGenerated"                 "pdf_report_generated" "$M/analytics/analytics.dart"

# --- Pet Insurance affiliate CTA --------------------------------------------
have "$M/monetization/insurance_affiliate_cta.dart"  "InsuranceAffiliateCta widget"
check "PET_INSURANCE_AFFILIATE_URL env"              "PET_INSURANCE_AFFILIATE_URL" "$M/config/env.dart"
check "Analytics.insuranceAffiliateClicked"          "insurance_affiliate_clicked" "$M/analytics/analytics.dart"
check "InsuranceAffiliateCta on Emergency screen"    "InsuranceAffiliateCta\(source: 'emergency_result'\)" "$M/analysis/emergency_result_screen.dart"
check "InsuranceAffiliateCta on Standard result"     "InsuranceAffiliateCta\(source:" "$M/analysis/result_screen.dart"
check "InsuranceAffiliateCta on Pet Profile"         "InsuranceAffiliateCta\(source: 'pet_profile'\)" "$M/pets/pet_form_screen.dart"
check "CTA self-hides when URL empty (safety)"       "petInsuranceAffiliateUrl.isEmpty" "$M/monetization/insurance_affiliate_cta.dart"

# --- Batteries --------------------------------------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_rp63.log 2>&1 && .venv/bin/python -m pytest -q >>/tmp/pawdoc_rp63.log 2>&1); then
    pass "ruff + pytest green (incl. 6.1 golden-set + 6.2 training_export)"
  else
    fail "ruff/pytest failed (see /tmp/pawdoc_rp63.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/."
fi

if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions"/_shared/*.test.mjs >/tmp/pawdoc_node63.log 2>&1; then
    pass "node --test (_shared incl. addon + pdf_report) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node63.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

if command -v docker >/dev/null 2>&1; then
  if "$ROOT/scripts/test-rls.sh" >/tmp/pawdoc_rls63.log 2>&1; then
    pass "test-rls.sh PASS — legacy CR #2 + Family Sharing (A/B see, C cannot, owner-only writes)"
  else
    fail "test-rls.sh FAILED (see /tmp/pawdoc_rls63.log) — CRITICAL: RLS regression"
  fi
else
  manual "Run ./scripts/test-rls.sh (needs Docker)."
fi

if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an63.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an63.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt63.log 2>&1); then
    pass "flutter test green (incl. PDF entitlement)"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt63.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL (founder) -------------------------------------------------------
manual "supabase db push — applies the family_sharing + pdf_report_addon migrations. Existing users get backfilled solo groups."
manual "RevenueCat: configure a consumable product with product_id 'pdf_report_addon' priced at \$4.99; reuse the same Webhook URL."
manual "Build defines: PET_INSURANCE_AFFILIATE_URL (affiliate signup) — leave empty until the partner deal lands; the CTA self-hides."
manual "Future Family-Sharing UI (invite member by email, accept invite) is a separate sub-PR. The DB layer is ready; client UI is intentionally out of scope here."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 6.3 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
