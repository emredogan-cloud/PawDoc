#!/usr/bin/env bash
# =============================================================================
# verify-phase-2.1.sh — Production Polish & Hardening checklist.
# Structural checks for CR #8 (moderation), CR #9 (account deletion), OneSignal,
# accessibility, offline, deep links + the real test runs (flutter, pytest, RLS
# + cascade). Device QA (push, dark mode) is MANUAL.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/mobile"; FN="$ROOT/supabase/functions"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -rq "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }

hr; echo "Phase 2.1 — Production Polish & Hardening"; hr

# --- CR #8 NSFW moderation ---------------------------------------------------
check "moderation gate runs before analysis" 'self.moderator.is_safe' "$ROOT/ai-service/app/pipeline.py"
check "moderator module present" 'class GeminiModerator' "$ROOT/ai-service/app/moderation.py"
check "Edge Function deletes R2 object on reject" 'deleteR2Object' "$FN/analyze/index.ts"

# --- CR #9 Account deletion --------------------------------------------------
check "delete-account Edge Function deletes the auth user" 'admin.auth.admin.deleteUser' "$FN/delete-account/index.ts"
check "delete-account deletes ONLY the caller (from JWT)" 'deleteUser(user.id)' "$FN/delete-account/index.ts"
check "in-app delete screen with typed confirmation" 'delete_confirm_field' "$MOBILE/lib/src/account/delete_account_screen.dart"
check "deletion cascade test present" 'ACCOUNT DELETION CASCADE OK' "$ROOT/supabase/tests/account_deletion.sql"

# --- OneSignal ---------------------------------------------------------------
check "OneSignal service syncs player_id" 'one_signal_player_id' "$MOBILE/lib/src/notifications/onesignal_service.dart"
check "OneSignal initialized in bootstrap" 'OneSignalService.initialize' "$MOBILE/lib/main.dart"
check "permission wired to onboarding Screen 4" 'requestPermissionAndSync' "$MOBILE/lib/src/onboarding/onboarding_flow.dart"

# --- Accessibility / offline / deep links / splash ---------------------------
check "accessibility Semantics in delete flow" 'Semantics(' "$MOBILE/lib/src/account/delete_account_screen.dart"
check "offline graceful messaging" 'No internet connection' "$MOBILE/lib/src/core/connectivity.dart"
check "referral deep-link route" "/r/:code" "$MOBILE/lib/src/router/app_router.dart"
check "Android pawdoc:// deep-link filter" 'android:scheme="pawdoc"' "$MOBILE/android/app/src/main/AndroidManifest.xml"
check "native splash configured" 'flutter_native_splash' "$MOBILE/pubspec.yaml"

# --- Real test runs ----------------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  if ( cd "$MOBILE" && flutter analyze >/tmp/p21a.log 2>&1 ); then pass "flutter analyze: no issues"; else fail "flutter analyze failed (/tmp/p21a.log)"; fi
  if ( cd "$MOBILE" && flutter test >/tmp/p21t.log 2>&1 ); then
    pass "flutter test: $(grep -oE 'All tests passed|[0-9]+ tests? passed' /tmp/p21t.log | tail -1)"
  else
    fail "flutter test failed (/tmp/p21t.log)"
  fi
fi
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if ( cd "$ROOT/ai-service" && .venv/bin/python -m pytest -q >/tmp/p21p.log 2>&1 ); then
    pass "ai-service pytest: $(grep -oE '[0-9]+ passed' /tmp/p21p.log | head -1) (incl. CR #8 moderation gate)"
  else
    fail "ai-service pytest failed (/tmp/p21p.log)"
  fi
fi
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
  if "$ROOT/scripts/test-rls.sh" >/tmp/p21rls.log 2>&1; then pass "RLS + CR #9 cascade test passed"; else fail "RLS/cascade test failed (/tmp/p21rls.log)"; fi
fi

# --- MANUAL ------------------------------------------------------------------
manual "Device: push permission prompt on Screen 4 -> player_id appears in users; dark mode renders correctly."
manual "Device: VoiceOver/TalkBack navigates all interactive elements; dynamic type scales without clipping."
manual "Device: Delete account removes the user (Supabase Auth) + cascades; app returns to sign-in."

hr
if [ "$fails" -eq 0 ]; then echo "Verifiable checks GREEN. Confirm MANUAL items on a device (runbook 17)."; exit 0; else echo "$fails check(s) FAILED."; exit 1; fi
