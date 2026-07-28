# PawDoc — Final Release Ready Report

**Date:** 2026-07-27 · **Branch:** `chore/final-prod-cleanup-release` · **PR:** [#91](https://github.com/emredogan-cloud/PawDoc/pull/91)
**Build:** 1.0.0+5 · **Device:** Redmi Note 8 (M1908C3JGG, Android 11), release APK over ADB
**Scope:** repository cleanup + focused validation of the two newly-configured
integrations (Google OAuth, RevenueCat) + the release artifact. No full-app
regression was run — that was explicitly out of scope for this mission.

---

## 1. Repository cleanup

The root held **75 markdown files**, almost all point-in-time development
reports. Every root report whose last commit predated **2026-07-23** (the
4-day cutoff) was moved into `docs/archive/YYYY-MM/`, filed by the month of its
last substantive commit.

| | |
| --- | --- |
| Archived | **64 files** (46 → `2026-06/`, 18 → `2026-07/`) |
| Method | `git mv` — all 64 registered as renames, so `git log --follow` reads through the move |
| Deleted | **0** |
| Root `.md` before → after | **75 → 11** |

Also done:
- Added `docs/archive/README.md` — what is in the archive, how it is filed, and a table pointing at where the *current* documentation lives.
- Replaced the 9-byte root `README.md` with a real navigation index (layout, docs map, common commands, safety invariants).
- Repointed the four references from still-active files at their new archive paths (`docs/contracts/ANALYSIS_RESULT.md`, `IMPLEMENTATION_CHANGELOG.md`, `LEGAL_CONTENT_APPENDIX.md`, `memory/PAST_DECISIONS.md`). All other cross-references were archive→archive and moved together.

### Kept at root (11)

| File | Why |
| --- | --- |
| `README.md` | Protected + rewritten as the index |
| `CLAUDE.md` | Active project instructions, loaded every session |
| `ENVIRONMENT_SETUP.md` | Current setup / production documentation |
| `IMPLEMENTATION_CHANGELOG.md` | The changelog (protected category) |
| `LEGAL_CONTENT_APPENDIX.md` | Source of truth for the **live** legal portal |
| `PAWDOC_FINAL_RELEASE_APPROVAL_REPORT.md` · `PAWDOC_NEXT_EVOLUTION_REPORT.md` · `PAWDOC_NEXT_EVOLUTION_ROADMAP.md` · `PAWDOC_PRODUCT_EVOLUTION.md` | Within the 4-day window (2026-07-24) |
| `PAWDOC_INTERNAL_TEST_FINAL_READY.md` | Within the window (2026-07-25) |
| `POST_BETA_POLISH_REPORT.md` | Within the window (2026-07-26) |

Nothing in `docs/runbooks/`, `docs/contracts/`, `docs/legal/`, `roadmap/`,
`memory/`, or `sub-pr-report/` was touched.

**Security note (unchanged, verified):** four secret-bearing files sit untracked
at the repo root — the Google OAuth `client_secret_*.json`, the GCP service
account `pawdoc-prod-*.json`, and `.env` / `prd_secrets.env` / `temp_prod.env` /
`doppler.env`. All are confirmed **untracked *and* gitignored**. Continue to
stage explicitly; never `git add -A`.

---

## 2. Google Sign-In validation

Configuration confirmed present in Doppler `prd`: `GOOGLE_WEB_CLIENT_ID` (72
chars) and `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` / `_SECRET`. The build was
wired with `--dart-define=GOOGLE_WEB_CLIENT_ID=…`.

| Check | Result | Evidence |
| --- | --- | --- |
| Google Sign-In button | **PASS** | "Continue with Google" renders; correctly **disabled until Terms is accepted** — no dead control |
| Account picker | **PASS** | Native picker, correct app name + icon. That it appears at all proves the Android OAuth client SHA-1 is registered (a mismatch yields `DEVELOPER_ERROR` and no picker) |
| Consent screen | **N/A this run** | Consent was previously granted for this OAuth client, so Google skipped it — expected behaviour, not a gap |
| First login | **PASS** | Landed on a fresh account ("Add your first pet") |
| New account creation | **PASS** | `public.users` provisioned — proven by successfully creating a pet, which requires the row, its referral code, and its solo family group (the `pets_default_family_group` trigger fails without them) |
| Existing / returning login | **PASS** | Signed out, signed back in with the same Google account → **same** PawDoc account with the pet intact |
| Duplicate account prevention | **PASS** | Same as above: a duplicate `auth.users` row would have produced an empty account. It did not |
| Duplicate identity prevention | **PASS** | The same Google identity resolved to the same user across three separate sign-ins |
| Session restore | **PASS** | Force-stop + relaunch → straight to Home, no re-auth |
| Logout | **PASS** | Confirmation dialog, then clean return to sign-in |
| Delete account | **PASS** | GDPR-grade screen (explicit inventory + type-`DELETE` gate). Deletion completed and signed out |
| Login after deletion | **PASS** | A fresh, empty account. Quota reset to 5/5 |
| Orphan-record prevention | **PASS** | After deletion + clean install + sign-in, the account was genuinely empty — no pets, no quota carry-over |
| Supabase identity / `public.users` | **PASS (code + behaviour)** | `on_auth_user_created` fires `AFTER INSERT` in the same transaction and is idempotent (`on conflict (id) do nothing`), so an auth user cannot exist without a profile row |

**One bug found and fixed here — see §5, bug 1.** Direct SQL/admin verification
of `auth.identities` was not performed: it requires a `service_role` bulk read of
user data, which the project's own standing rule forbids. Integrity was
established functionally instead (a second login landing on the same account is
the property that actually matters), plus code-level review of the trigger.

---

## 3. RevenueCat validation

`REVENUECAT_PUBLIC_SDK_KEY_ANDROID` (32 chars) confirmed in Doppler `prd` and
compiled in. This is the first build in which the SDK is actually configured —
previously the Subscription tile was inert and the paywall showed "coming soon".

| Check | Result | Evidence |
| --- | --- | --- |
| SDK initialization | **PASS** | `Purchases.configure` succeeded; the Account tile is live ("Upgrade to Premium") instead of hanging |
| Product loading | **PARTIAL** | **Monthly loads** with a real localized Play price (`₺569,99`). **Annual does not resolve** — founder-side config, see §8 |
| Paywall | **PASS (after fix)** | Renders value stack, auto-renew disclosure, Subscription Terms / Terms / Privacy links, Restore, Not now |
| Purchase | **BLOCKED — environment, not a defect** | Play returns `DEVELOPER_ERROR` with its own message: *"Please ensure the specific App version has been published."* A side-loaded, upload-key-signed APK can never transact through Play Billing. Logcat confirms the app correctly reached `ProxyBillingActivity` → Finsky; Play refused it |
| Sandbox purchase | **BLOCKED — same reason** | Requires a Play-distributed build + a licensed tester account |
| Restore purchase | **PASS** | Returned the honest "No previous purchase found for this store account." — correct, since none exists |
| Entitlement / premium unlock / persistence / reinstall / Premium Welcome | **NOT VERIFIABLE** | All sit behind a completed purchase, which the environment cannot produce |
| Internal tester account | **PASS (code)** | `internal_tester` defined once in `supabase/functions/_shared/premium.mjs`, mirrored exactly in `user_profile.dart` (`{premium, trial, internal_tester}` — parity confirmed). Service-role grant only; `authenticated` holds no UPDATE grant on `public.users`, so self-granting fails with 42501 before RLS is consulted |
| Normal users still require purchase | **PASS** | The test account showed "Free plan · text checks free · 5 of 5 photo logs left" throughout. No debug/premium bypass branch exists |

**Two bugs found and fixed here — see §5, bugs 2 and 3.**

---

## 4. Bugs found

| # | Severity | Area | Summary |
| --- | --- | --- | --- |
| 1 | **High** | Auth / privacy | Deleting an account and signing in again showed the **deleted account's pet**. Root cause: `currentUserIdProvider` had no reactive dependency, so all seven user-scoped providers kept serving the previous identity's cache |
| 2 | **High** | Monetization / compliance | Paywall showed **two currencies at once** — a hardcoded `$39.99 / year` beside a real `₺569,99` — under a constant `Save 52%` badge that was arithmetic against neither, with a live buy button for a package that had not loaded |
| 3 | **Medium** | Monetization / UX | A failed purchase dumped the entire raw `PlatformException` (`readableErrorCode`, `DebugMessage`, `SubResponseCode: NO_APPLICABLE_SUB_RESPONSE_CODE`, …) into a snackbar. User cancellation was also reported as an error |

### Bug 1 in detail — the root cause PR #88 missed

`pets_repository.dart` already carried a comment describing this exact symptom
as fixed. It wasn't. The intended fix made user-scoped providers watch
`currentUserIdProvider`, but that provider was itself frozen:

```dart
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});
```

`supabaseClientProvider` returns a singleton that never changes, so the provider
was computed **once per process and never recomputed**. Every dependant watched
a constant. Affected: pets, memories, assistant, community (×2), pending
follow-up, and `user_profile` — which carries `subscription_status`, so premium
state was in the same blast radius.

`account_switch_isolation_test` passed only because it called
`container.invalidate(currentUserIdProvider)` **by hand**, simulating a
recomputation production never performed. The test proved the downstream wiring
and never the thing that was broken.

**Server-side deletion was correct throughout.** A clean install + fresh sign-in
showed the account genuinely empty, so this was a client cache-invalidation
defect, not a data-retention or GDPR-erasure failure.

---

## 5. Bugs fixed

All three fixed, unit-tested, and **re-verified on the device against a rebuilt
APK**.

**1. Account bleed-through** — identity now derives from
`currentSessionProvider`, which *is* correctly wired to the auth stream:

```dart
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentSessionProvider)?.user.id;
});
```

New `test/current_user_id_reactivity_test.dart` (3 tests) pins the reactivity
itself — identity tracks a changing session, clears to null on sign-out, and is
derived from the session provider rather than a frozen singleton.
*Device re-verified:* created pet "BleedCheck" → deleted the account → signed
back in **in the same process** → Home and My Pets both correctly empty. Before
the fix the identical sequence retained the pet.

**2. Mixed-currency paywall** — plan cards are now built **only** for packages
the store actually returned; no placeholder price and no buy button for a
package that did not load. The per-month line uses the store's own
`pricePerMonthString`, and the savings badge is computed from real prices, in a
single currency, or omitted. An offering that resolves zero packages falls back
to the existing "coming soon" state rather than an empty void. Extracted to
`paywall_pricing.dart` with `test/paywall_pricing_test.dart` (10 tests).
*Device re-verified:* the fabricated `$39.99` card and the `Save 52%` badge are
gone; only the real `₺569,99` monthly renders, correctly promoted to the
featured CTA.

**3. Purchase error copy** — `purchase_error_message.dart` maps every
`PurchasesErrorCode` to one human sentence; **user cancellation returns null and
shows nothing**; pending payments read as pending rather than failure; the
previously silent "succeeded but no entitlement" path now speaks.
`test/purchase_error_message_test.dart` (8 tests) asserts every non-cancel code
yields copy containing none of `PlatformException`, `DebugMessage`,
`SubResponseCode`, `DEVELOPER_ERROR`, braces, or `null`.
*Device re-verified:* the 15-line dump is replaced by *"Purchases are not
available in this copy of PawDoc. If you installed it outside Google Play,
install it from Play and try again."*

---

## 6. Test and CI status

### Local

| Suite | Result |
| --- | --- |
| `flutter analyze` | **Clean** — "No issues found!" |
| `flutter test` | **359 passed**, 1 skipped (338 before; **+21 new**) |
| `node --test supabase/functions/_shared/*.test.mjs` | **78 passed**, 0 failed |

### GitHub Actions — PR #91, run [30284728458](https://github.com/emredogan-cloud/PawDoc/actions/runs/30284728458)

**7 / 7 green.**

| Check | Result | Time |
| --- | --- | --- |
| Flutter analyze + test + build | **pass** | 21m32s |
| AI service — ruff + pytest | **pass** | 24s |
| Edge shared tests (`node --test`) | **pass** | 13s |
| RLS + deletion cascade (full migrations, Docker pg) | **pass** | 21s |
| Secret scan (gitleaks) | **pass** | 7s |
| No placeholders / overclaims | **pass** | 7s |
| ShellCheck (scripts) | **pass** | 10s |

Two of these are worth calling out for this particular change set: **gitleaks
passed**, confirming the 64-file archive move exposed no secrets, and the **RLS +
deletion-cascade** job passed against the full migration set, independently
corroborating that server-side account deletion is sound (bug 1 was a client
cache defect, not a data-retention one).

---

## 7. Release AAB

| Property | Value |
| --- | --- |
| Path | `mobile/build/app/outputs/bundle/release/app-release.aab` |
| Size | 100,506,089 bytes (~95.9 MiB) |
| SHA-256 | `c71c65d46b9eb0b74baafeebe241a6f4daa6c88ae3051bf92cebb451fabc0ed0` |
| versionName | **1.0.0** (read from the bundle manifest) |
| versionCode | **5** (read from the bundle manifest) |
| Package | `app.pawdoc` |
| Build type | Release |
| Signing | Upload key, alias `UPLOAD` (`META-INF/UPLOAD.RSA`) |
| Cert SHA-1 | `B7:8F:8F:9B:EC:B2:F7:60:0D:4A:0C:CE:CF:C8:46:D1:FE:28:96:59` — matches the registered upload key |
| Cert SHA-256 | `E8:C3:09:40:57:A7:E2:B2:E7:D2:67:5C:80:6F:1B:AE:37:51:88:74:D6:ED:BF:17:9E:97:55:DC:A2:A7:38:8A` |
| Owner | `CN=Emre Dogan, OU=PawDoc, O=Pawdoc, L=Turkiye, ST=turkiye, C=90` |
| Cert validity | 2026-07-25 → 2053-12-10 |
| ABIs | `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| Configuration | Doppler `prd` — Supabase URL/anon key, `GOOGLE_WEB_CLIENT_ID`, `REVENUECAT_PUBLIC_SDK_KEY_ANDROID` |

versionCode 5 supersedes the 1.0.0+4 currently in closed testing.

---

## 8. Remaining founder-only tasks

**Blocking a complete RevenueCat sign-off:**

1. **Attach and activate the annual product.** Only `$rc_monthly` resolves; `offering.annual` returns null, so the annual plan does not render at all. Check that the annual subscription exists and is **active** in the Play Console, is attached to the current RevenueCat offering, and is available in the tester's country.
2. **Run the purchase E2E from a Play-installed build.** Upload this AAB to the closed-testing track, install via the tester opt-in link, and buy with a **licensed tester** account. This is the only way to exercise purchase → entitlement → premium unlock → persistence → reinstall → Premium Welcome. No side-loaded build can do it — Play returns `DEVELOPER_ERROR` by design.

**Non-blocking, worth noting:**

3. **`POSTHOG_API_KEY` and `SENTRY_DSN` are absent from Doppler `prd`.** The app degrades cleanly (analytics is off by default and consent-gated anyway), but this build ships with **no crash reporting and no analytics**. For closed testing that means crashes will be invisible outside Play's own vitals.
4. **`REVENUECAT_PUBLIC_SDK_KEY_IOS` is still `NOT YET`.** Irrelevant to Android; blocks any iOS work.
5. **Merge PR #91.** `main` is protected (linear history + review), so squash-merge is founder-gated.
6. **Verify the Google consent screen once on a fresh Google account** — this device had already granted consent, so that screen was skipped. Worth one pass with an account that has never authorized the app.

---

## 9. Verdict

**Is this build ready to continue Google Play Closed Testing?**

# YES WITH CONDITIONS

The conditions:

- **It is an improvement on what is live.** Build 1.0.0+4 is in closed testing today carrying all three defects — including a paywall that shows testers a price in the wrong currency and a fabricated discount, and an account-isolation bug that leaks the previous account's pet after deletion. Shipping 1.0.0+5 makes closed testing strictly better, and the two user-facing monetization defects are exactly the kind a tester would report as broken.
- **The purchase path is validated only as far as the environment allows.** SDK init, product loading, paywall render, restore, and error handling are confirmed on-device. Purchase, entitlement, premium unlock and persistence are **not** — they cannot be until the AAB is on a Play track. Treat the first Play-installed purchase as the real gate.
- **The annual plan is currently invisible to users.** With the fix in place the paywall honestly shows only the monthly plan rather than a fake dollar price, but the intended annual-first pricing strategy is not live until the founder fixes the product configuration.
- **This build has no crash reporting.** Add `SENTRY_DSN` before leaning on closed testing for stability signal.

Engineering work that could be completed from here is complete: repository
cleaned, three real bugs found, fixed, unit-tested and device-verified,
`flutter analyze` clean, 359 Flutter + 78 node tests green, **CI 7/7 green**,
and a correctly signed 1.0.0+5 AAB verified artifact-side.
