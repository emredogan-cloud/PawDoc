# SUB-PR Report — Phase 2.1: Production Polish & Hardening

**Status:** Built and **verified headless** (`flutter analyze` clean · 30 mobile tests · ai-service 45 pytest incl. CR #8 gate · RLS+CR #9 cascade · 19-check verifier). Device QA (push, dark mode, VoiceOver) is founder-side.
**Branch:** `phase-2.1-production-polish` (from updated `main` = 0.1–1.4)
**Date:** 2026-05-27

> Note: a transient network outage briefly blocked `git fetch`; once it cleared, this branch was re-based cleanly on `origin/main` (which had the squash-merged 1.4).

## 1. Files created / modified

```
ai-service/app/moderation.py                      CR #8 moderator (ImageModerator + Gemini/AllowAll)
ai-service/app/pipeline.py (M)                     moderation gate before analysis + moderation_rejected
ai-service/app/main.py (M)                         inject moderator + expose flag
ai-service/tests/test_pipeline.py (M)              CR #8 gate tests
supabase/functions/delete-account/index.ts         CR #9 — delete the caller (cascades)
supabase/functions/analyze/index.ts (M)            delete R2 object on moderation reject (CR #8)
supabase/tests/account_deletion.sql                CR #9 cascade test ; scripts/test-rls.sh (M)
mobile/lib/src/account/{account_service,delete_account_screen}.dart   CR #9 client flow
mobile/lib/src/notifications/onesignal_service.dart  OneSignal + player_id sync
mobile/lib/src/core/{connectivity,app_views}.dart    offline banner + error/empty/loading views
mobile/lib/src/referral/referral_prefs.dart          deep-link referral capture
mobile/lib/{main,src/config/env}.dart (M)            OneSignal init + ONESIGNAL_APP_ID
mobile/lib/src/onboarding/onboarding_flow.dart (M)   Screen 4 -> push permission + sync
mobile/lib/src/router/app_router.dart (M)            /r/:code deep-link route
mobile/lib/src/home/home_screen.dart (M)             offline banner + Delete-account menu
mobile/android/.../AndroidManifest.xml (M)           pawdoc:// deep-link filter
mobile/pubspec.yaml (M) + generated native splash    flutter_native_splash/_launcher_icons config
mobile/test/polish_test.dart                         delete-gate, a11y label, offline banner tests
scripts/verify-phase-2.1.sh ; docs/runbooks/17-...md ; ENVIRONMENT_VARS.md (M)
```

## 2. How CR #8 (NSFW) and CR #9 (Account Deletion) were implemented

**CR #8 — NSFW moderation** (`ai-service/app/moderation.py` + `pipeline.py`): an injectable
`ImageModerator` runs **before** the Tier-2/3 analysis. When the request has an image, the
pipeline calls `moderator.is_safe(image_url)`; if unsafe it returns a safe "We couldn't
process this image" result with `moderation_rejected=True` and **does not call the AI**. The
real `GeminiModerator` does a cheap vision safety check and **fails closed** (errors/blocks →
unsafe). The `analyze` Edge Function reads `meta.moderation_rejected` and **deletes the stored
R2 object** (`deleteR2Object`) so rejected uploads don't linger. Unit-tested:
`test_cr8_unsafe_image_rejected_before_analysis` (no analysis runs) and `..._safe_image_proceeds`.
*(Note: the strict "before R2" is approximated by delete-on-reject, since the client uploads
directly to R2 via presigned URL; a pre-upload client check is the alternative — surfaced.)*

**CR #9 — Account deletion** (`delete-account` Edge Function + `delete_account_screen.dart`):
the function takes the user **from the verified JWT** (never a body param, so a caller can only
delete themselves) and calls `admin.auth.admin.deleteUser(user.id)`. Because `public.users.id`
references `auth.users(id) ON DELETE CASCADE` and pets/analyses/reminders/referrals reference
`users ON DELETE CASCADE` (Phase 1.1 / CR #20), one delete wipes **all** the user's data. The
in-app flow (Apple 5.1.1(v)) is discoverable (home overflow menu), requires typing **DELETE**,
and signs out (router redirects to sign-in). The cascade is **proven headlessly** by
`supabase/tests/account_deletion.sql` (run via `test-rls.sh`): "ACCOUNT DELETION CASCADE OK".

## 3. How to test OneSignal & Account Deletion locally (full steps: runbook 17)

- **OneSignal:** build with `--dart-define=ONESIGNAL_APP_ID=<id>`; onboarding **Screen 4 →
  "Enable alerts"** triggers the OS push prompt; on grant,
  `select one_signal_player_id from public.users where id='<uid>'` is populated; send a test
  push from the OneSignal dashboard.
- **Account deletion:** deploy `delete-account`; Home → ⋮ → **Delete account** → type `DELETE`
  → confirm the user is gone in Supabase Auth + `public.users`/pets/analyses cascade-deleted +
  app returns to sign-in. No device needed for the logic: `./scripts/test-rls.sh` runs the
  cascade assertion.

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `flutter analyze` | No issues found |
| `flutter test` | **30 passed** — incl. delete-gate, accessibility label, offline banner |
| `ai-service pytest` | **45 passed** — incl. CR #8 moderation gate (×2) |
| `test-rls.sh` | RLS isolation + **CR #9 cascade** PASS |
| `verify-phase-2.1.sh` | exit 0 — 19 checks green |

## 5. Security / compliance checks

- **CR #9:** deletion is scoped to `auth.uid()` (cannot delete others); full GDPR/Apple erasure via cascade (proven).
- **CR #8:** unsafe images never reach the AI and are removed from R2; moderator fails closed.
- Accessibility: Semantics labels on key controls (delete flow asserted in tests); WCAG-AA Material 3 scheme; dynamic type.
- No new committed secrets (scan clean); deletion/moderation reuse existing service-role/AI keys.

## 6. Known issues / scope notes

- Push delivery, dark-mode rendering, VoiceOver/TalkBack navigation, and the live delete round-trip are **device-side** (runbook 17). Logic + labels are unit-tested.
- App **icon** generation needs a real asset (`flutter_launcher_icons` config added; founder supplies the PNG and runs it). The **splash** is generated (color-based) now.
- `GeminiModerator` real behavior needs a Google AI key; the gate logic is tested via a fake.
- Deep links: Android `pawdoc://` filter shipped; **iOS Universal Links / Android App Links** (https://pawdoc.app) need associated-domains/assetlinks setup (runbook 17, founder).

## 7. Risks

- Moderation via Gemini adds a call before analysis (latency/cost) — acceptable for safety; revisit a cheaper dedicated moderation if cost grows.
- Failing closed on moderation could reject borderline-but-valid images; the user is told to retake.

## 8. Git branch

`phase-2.1-production-polish`

## 9. Commit hash

Implementation commit: `__IMPL_COMMIT__` (finalized in report-finalization commit; see `git log`).

## 10. Push confirmation

`__PUSH_STATUS__`

## 11. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| Loading/error/empty/offline states | ✅ built | app_views + OfflineBanner + tests |
| Deep links (referral) | ✅ built | /r/:code route + Android filter |
| Accessibility (Semantics, contrast, dynamic type) | ✅ built / ⏳ device | Semantics + a11y label test; device QA per runbook 17 |
| Dark mode | ✅ built / ⏳ device | ThemeMode.system + AppTheme.dark() |
| OneSignal + permission on Screen 4 + player_id sync | ✅ built / ⏳ device | onesignal_service + Screen 4 wiring |
| App icon + splash infra | ✅ splash generated / icon config | pubspec + native splash |
| **CR #8 NSFW moderation** | ✅ DONE | gate + tests; R2 delete-on-reject |
| **CR #9 account deletion** | ✅ DONE | function + screen; cascade test PASS |

**Verified now:** moderation gate, deletion cascade, the polish/offline/a11y widgets, and compilation. **Device-side:** push, dark mode, VoiceOver, and the live deletion round-trip — all in runbook 17. Next per roadmap: **Phase 2.2 (Legal, Compliance & Trust Gate)**.
