# APK Provenance Report — Phase 3
**2026-06-13** · the exact artifact used in the last device validation.

- **Path:** `mobile/build/app/outputs/flutter-apk/app-release.apk`
- **Build timestamp:** 2026-06-13 **14:08** (+ a later locale-fix rebuild ~14:1x; both from main)
- **Version:** `1.0.0` (versionCode 1)
- **Built from:** `main @ d167ed0` via `doppler run -p pawdoc -c dev -- flutter build apk --release --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`
- **Signing:** debug (release keystore is founder-gated, B1)

## Was it freshly built? → YES.
The APK was built fresh during this session (not a stale artifact). Timestamps +
the from-scratch `assembleRelease` confirm it.

## Was a stale APK installed? → NO — but the WRONG BRANCH was built.
The fresh build was from **main**, which does **not** contain `ui-translation`.
So the validation ran a current build of the *earlier* UI. The defect is not
staleness — it is **source branch**: main lacks the new UI (Phase 1/2). The
pre-session installed build (v1.0.0, 2026-06-11/12) was even older and also
pre-ui-translation.
