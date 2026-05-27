# SUB-PR Report — Phase 1.1: App Skeleton, Auth & Data Layer

**Status:** Built and **verified headless** — app compiles & tests pass; the corrected RLS is proven against real Postgres. Device sign-in + live-Supabase steps are founder-side.
**Branch:** `phase-1.1-app-skeleton-auth-data` (from updated `main`, which now includes Phase 0.4)
**Date:** 2026-05-27

---

## 1. What was implemented

- **Flutter app skeleton** (`mobile/`): Riverpod + go_router + Material 3 theme (teal `#00897B` / amber `#FFB300`, dark mode follows system). Auth-gated routing via a `GoRouter` redirect that refreshes on the Supabase auth stream.
- **Supabase client + auth-state provider** (`supabase_providers.dart`): client provider, `authStateChangesProvider` (Stream), `currentSessionProvider`.
- **Auth flows** (`auth_controller.dart`, `sign_in_screen.dart`): email sign-in/sign-up + **Sign in with Apple** (correct nonce: SHA-256 to Apple, raw to Supabase). Sign-out on the home screen.
- **Migration v1** (`supabase/migrations/`): all **7 tables** + **7 indexes** per Section 5, with owner-approved corrections (see §5).
- **Edge Function `/auth-webhook`**: verifies the webhook signature (CR #21) then provisions `public.users` via the service role; declared `verify_jwt = false`.
- **Sentry** initialized early in `main()` (guarded on `SENTRY_DSN`).
- **`AnalysisResult` contract frozen** (CR #16): Dart binding + `docs/contracts/ANALYSIS_RESULT.md` as the cross-language source of truth.
- **RLS isolation test** (`scripts/test-rls.sh` + `supabase/tests/`): repeatable proof of cross-user isolation against real Postgres+pgvector.

## 2. Deviation from the roadmap (transparent)

- **Riverpod 3.3 / go_router 17 / supabase_flutter 2.12 / sign_in_with_apple 8 / sentry_flutter 8** were resolved by `flutter pub add` against **Dart 3.11**. The roadmap said "Riverpod 2.x"; 3.x is what's compatible with the current SDK. Only the stable API subset is used (Provider/StreamProvider/ConsumerWidget). Flagged, not silently buried.

## 3. Corrections applied (owner-approved CR #2 + #20 + #21)

- **CR #2 (RLS):** RLS enabled on **all seven** user-data tables with complete `USING` + `WITH CHECK` policies (the source had no `WITH CHECK`/INSERT path, deny-all on two tables, and no RLS on three). `public.users.id` now references `auth.users(id)` so `auth.uid() = user_id` can actually match — without this the policies can never function.
- **CR #20 (FK `ON DELETE`):** added `ON DELETE CASCADE` to `analyses.pet_id/user_id`, `reminders.user_id`, `analysis_feedback.analysis_id`, `referrals.referrer_user_id` (the source omitted them, which would block deletes / orphan rows).
- **CR #21 (webhook signature):** `/auth-webhook` rejects unsigned/forged requests (401) before any DB write.
- **Surfaced, NOT applied:** CR #9 (legal-hold vs GDPR erasure — Phase 2 decision; CASCADE here supports erasure); a Postgres `on auth.users` trigger as a more robust alternative to the webhook.

## 4. Files changed (summary)

```
mobile/                              full Flutter project (lib/src/{config,models,theme,auth,home,router}, main.dart, tests)
supabase/migrations/20260527010000_initial_schema.sql   7 tables + 7 indexes (+CR #20)
supabase/migrations/20260527010001_rls_policies.sql     corrected RLS (CR #2)
supabase/functions/auth-webhook/index.ts                signed webhook (CR #21)
supabase/config.toml                                    [functions.auth-webhook] verify_jwt=false
supabase/tests/{_local_shim,rls_isolation}.sql          RLS isolation test
scripts/test-rls.sh, scripts/verify-phase-1.1.sh        verification harnesses
docs/contracts/ANALYSIS_RESULT.md                       frozen contract (CR #16)
docs/runbooks/13-auth-webhook.md
ENVIRONMENT_VARS.md (M)                                 SUPABASE_AUTH_WEBHOOK_SECRET + --dart-define notes
```

## 5. Tests executed & results

| Test | Result |
|------|--------|
| `flutter analyze` | **No issues found** |
| `flutter test` (AnalysisResult contract ×4, SignInScreen widget ×2) | **6 passed** |
| `./scripts/test-rls.sh` (real Postgres+pgvector: migrations applied, cross-user isolation) | **PASS** — A cannot read/write B's pets/analyses/health_events; WITH CHECK blocks cross-user insert; own-row insert allowed |
| `./scripts/verify-phase-1.1.sh` | **exit 0** — 7 verifiable PASS, 3 MANUAL |

## 6. Security checks

- **Cross-user isolation proven**, not assumed (the RLS test exercises real policies on real Postgres).
- Webhook is **signature-verified** (CR #21); `service_role` is server-only; the anon key is the only key compiled into the client (public by design, RLS-guarded).
- No secrets committed (verified); secrets flow via `--dart-define`/Doppler.

## 7. Known issues

- **Device-dependent DoD is founder-side** (headless env): running to a signed-in state on iOS simulator/Android emulator, the email/Apple → `users`-row round-trip via the deployed webhook, and the Sentry test event. All have runbooks (13) / clear steps.
- **Apple sign-in** needs the Supabase Apple provider configured, which is gated on Apple Developer approval (Phase 0.1, in review). Email + the nonce flow are implemented; the device path is untestable here.

## 8. Risks

- **Riverpod 3 deviation** — mitigated by using only stable APIs and `flutter analyze` (clean).
- **Apple nonce flow** is correct-by-construction but unverified on a device.
- **Webhook robustness** — a `users` row depends on hook delivery; the DB-trigger alternative is surfaced if delivery proves flaky.

## 9. Git branch

`phase-1.1-app-skeleton-auth-data`

## 10. Commit hash

Implementation commit: `__IMPL_COMMIT__` (finalized in report-finalization commit; see `git log`).

## 11. Push confirmation

`__PUSH_STATUS__`

## 12. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| App compiles & runs to a signed-in state (iOS sim + Android emu) | ⏳ compiles ✅ / device run MANUAL | `flutter analyze` clean, `flutter test` green; device run needs Supabase `--dart-define` |
| Email + Apple sign-in create a `users` row via `/auth-webhook` | ⏳ built / MANUAL | function + runbook 13; live verify on device |
| **RLS: user A cannot read/write user B's rows** | ✅ **DONE** | `test-rls.sh` PASS on real Postgres (pets/analyses/health_events) |
| All Section-5 indexes exist | ✅ DONE | 7 indexes created; migration applied cleanly in the RLS harness |
| Sentry receives a test exception | ⏳ MANUAL | init wired; throw-on-device to confirm |

**Verified now:** the app builds & tests pass, and the corrected RLS is provably enforced. **Founder-side:** device sign-in, the live webhook round-trip, and the Sentry event — each with a runbook.
