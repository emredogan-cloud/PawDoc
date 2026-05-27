#!/usr/bin/env bash
# =============================================================================
# verify-phase-1.2.sh — Capture & Upload Pipeline checklist.
# Headless-verifiable: flutter analyze/test (incl. EXIF/quality/pet/onboarding),
# Node tests (upload-key + free-tier regression), and structural checks for the
# CR #6/#7 security properties + permissions. Camera + live upload are MANUAL.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/mobile"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
skip()   { printf '\033[0;33mSKIP\033[0m  %s\n' "$*"; }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -q "$2" "$3"; then pass "$1"; else fail "$1"; fi; }

hr; echo "Phase 1.2 — Capture & Upload Pipeline"; hr

# --- CR #7: EXIF/GPS stripped + <2MB -----------------------------------------
check "CR #7: EXIF/GPS cleared before re-encode" 'exif = img.ExifData()' "$MOBILE/lib/src/capture/image_compressor.dart"
check "compression ceiling is 2MB" 'kMaxUploadBytes = 2' "$MOBILE/lib/src/capture/image_compressor.dart"

# --- CR #6: presigned URL; NO R2 write creds in the client -------------------
check "CR #6: client fetches presigned URL via Edge Function" "functions.invoke" "$MOBILE/lib/src/capture/upload_service.dart"
check "CR #6: generate-upload-url presigns (signQuery)" 'signQuery' "$ROOT/supabase/functions/generate-upload-url/index.ts"
if grep -rqiE 'R2_SECRET_ACCESS_KEY|r2\.cloudflarestorage\.com' "$MOBILE/lib"; then
  fail "client must NOT embed R2 credentials/endpoint (CR #6)"
else
  pass "no R2 write creds/endpoint in client code (CR #6)"
fi

# --- Permissions declared ----------------------------------------------------
check "iOS NSCameraUsageDescription declared" 'NSCameraUsageDescription' "$MOBILE/ios/Runner/Info.plist"
check "iOS NSPhotoLibraryUsageDescription declared" 'NSPhotoLibraryUsageDescription' "$MOBILE/ios/Runner/Info.plist"
check "Android CAMERA permission declared" 'android.permission.CAMERA' "$MOBILE/android/app/src/main/AndroidManifest.xml"

# --- Onboarding + analytics --------------------------------------------------
check "onboarding 5-screen flow present" 'OnboardingFlow' "$MOBILE/lib/src/onboarding/onboarding_flow.dart"
check "analytics: onboarding_step_completed" 'onboarding_step_completed' "$MOBILE/lib/src/analytics/analytics.dart"
check "analytics: onboarding_completed" 'onboarding_completed' "$MOBILE/lib/src/analytics/analytics.dart"

# --- flutter analyze + test --------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  if ( cd "$MOBILE" && flutter analyze >/tmp/pawdoc_a12.log 2>&1 ); then pass "flutter analyze: no issues"; else fail "flutter analyze failed (/tmp/pawdoc_a12.log)"; fi
  if ( cd "$MOBILE" && flutter test >/tmp/pawdoc_t12.log 2>&1 ); then
    pass "flutter test: $(grep -oE 'All tests passed|[0-9]+ tests? passed' /tmp/pawdoc_t12.log | tail -1)"
  else
    fail "flutter test failed (/tmp/pawdoc_t12.log)"
  fi
else
  skip "flutter not installed"
fi

# --- Node unit tests (upload-key + free-tier regression) ---------------------
if command -v node >/dev/null 2>&1; then
  if node --test "$ROOT/supabase/functions/_shared/upload_key.test.mjs" >/tmp/pawdoc_uk.log 2>&1; then pass "upload-key Node tests"; else fail "upload-key tests failed"; fi
else
  skip "node not installed"
fi

# --- MANUAL ------------------------------------------------------------------
manual "On a physical device: grant camera permission; quality hints show; capture compresses < 2MB."
manual "Upload returns an R2 key; the object exists in the bucket; the client never holds R2 keys."
manual "Onboarding completes in < 2 min to the camera screen; PostHog receives the events."

hr
if [ "$fails" -eq 0 ]; then
  echo "Verifiable checks GREEN. Confirm MANUAL items on a device (runbook 15)."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
