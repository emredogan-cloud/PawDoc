# PawDoc — Sprint 2 Execution Report
**Auth Lifecycle & Release Surface** · 2026-06-13 · agent-executed, founder-gated merges

## Executive summary
All 11 in-scope Sprint-2 findings are **CLOSED with evidence**: E16, E1, E3, E5,
E6, E9, E10, E12, B2, B3, B5. One branch per finding (`fix/<name>`), each
verified → fixed → validated → committed → pushed. No production deploys (single
prod project, founder-gated). `gh` is unauthenticated here, so branches are
pushed and the founder squash-merges.

Every fix was validated against real tooling — `flutter analyze`/`flutter test`,
`flutter build apk --debug`, `node --test`, `scripts/test-rls.sh` (Docker
Postgres), and the merged Android manifest — not assumed. Two findings surfaced
**latent defects the reports didn't predict**: B5 found a fabricated-testimonials
block on the live marketing site *and* a truthfulness gate that silently passed
by treating emoji-laden copy as binary; B2 found the iOS icon carried an alpha
channel (a guaranteed App Store rejection).

## Findings closed — branch · SHA · evidence

| # | Branch | SHA | What shipped | Validation |
|---|--------|-----|--------------|------------|
| **E16** | `fix/e16-quota-ux` | `bd57abf` | Symptom min 20→12 + emergency-keyword bypass (e.g. "choking" never blocked); referral bonus-cap migration | 4 widget tests; `test-rls` PASS |
| **E1** | `fix/e1-password-reset` | `89d9d9d` | Forgot-password dialog + `RecoveryScreen` + `/recovery` route + `passwordRecovery` listener | analyze clean; `widget_test` 5/5; apk OK |
| **E3** | `fix/e3-auth-hardening` | `e765635` | Apple sign-in gated to iOS/macOS; client min-pw 6→8 | analyze clean; `widget_test` 5/5 (iOS-shows / Android-hides); apk OK |
| **E5** | `fix/e5-rc-idempotency` | `b21b534` | `processed_rc_events` pk ledger (claim before credit, release-on-failure) + constant-time webhook auth | `node --test` 87/87 (+6 new); `test-rls` PASS |
| **E6** | `fix/e6-onesignal-logout` | `86cf9ff` | Clear OneSignal/RevenueCat/PostHog identities on `signedOut`; `allowBackup=false` | analyze clean; apk OK |
| **E9** | `fix/e9-invite-fallback` | `bee3a5d` | `parseInviteToken` + manual invite-entry dialog → existing `/invite/:token` accept | `invite_token_test` 5/5; apk OK |
| **E10** | `fix/e10-pdf-upsell` | `fb55b46` | PDF 402 dead-end snackbar → actionable "Unlock" → paywall | `pdf_entitlement_test` 3/3; apk OK |
| **E12** | `fix/e12-family-hardening` | `22752aa` | pets/analyses/reminders UPDATE `WITH CHECK` re-asserts family membership; family Upgrade→paywall | `test-rls` PASS incl. new ASSERT 10 (cross-tenant move blocked) |
| **B2** | `fix/b2-launcher-icon` | `0493106` | Adaptive Android icon + full iOS set (alpha removed); "PawDoc" display name | generator OK; 1024 icon verified RGB; apk OK |
| **B3** | `fix/b3-permission-diet` | `8cc5419` | Removed RECORD_AUDIO / READ_MEDIA_IMAGES / READ+WRITE_EXTERNAL_STORAGE + iOS NSPhotoLibrary | merged-manifest before/after proof; apk OK |
| **B5** | `fix/b5-truthfulness-gate` | `fe427a5` | Truthified store+web overclaims (incl. fabricated testimonials); rebuilt `verify-no-placeholders.sh` | forced-failure proof; default exit 0 / `--strict` exit 1 |

## Notable discoveries (reality over reports)
- **B5 / fabricated testimonials.** `web/app/page.tsx` shipped three fake quotes
  ("Sarah M.", "Diego R.", "Priya K.") under "Pet parents trust PawDoc", plus
  false "vet-reviewed" (blog) and "attorney-reviewed" (legal footer) claims.
  Removed; replaced with the app's true, enforced guarantees.
- **B5 / the gate didn't gate.** `verify-no-placeholders.sh` used `grep -I`,
  which classified every emoji/em-dash file (i.e. *all* the launch copy) as
  binary and skipped it — passing by not looking. Switched to `-a`; that change
  alone surfaced the testimonials. Now split into OVERCLAIMS (engineering
  ship-blocker; default CI run) and PLACEHOLDERS (founder fill-ins; `--strict`).
- **B2 / iOS alpha.** The source icon was RGBA; the App Store rejects alpha. Set
  `remove_alpha_ios` and re-generated — the 1024 icon is now flattened RGB.
- **E12 / cross-tenant injection.** The pets UPDATE policy let an owner re-point
  `family_group_id` to a stranger's group (SELECT is membership-based, so the
  pet would appear in that family's feed). Now WITH CHECK re-asserts membership
  on the new row, for pets *and* analyses *and* reminders.

## Validation commands run
- `flutter analyze` (clean), `flutter test test/widget_test.dart`,
  `test/invite_token_test.dart`, `test/pdf_entitlement_test.dart`
- `flutter build apk --debug` (every mobile finding)
- `node --test supabase/functions/_shared/*.test.mjs` (87/87)
- `./scripts/test-rls.sh` (E5 + E12 migrations applied to real Postgres; RLS
  isolation + family ASSERT 10 PASS)
- Merged Android manifest permission diff (B3 before/after)
- `./scripts/verify-no-placeholders.sh` + `--strict` + forced-failure probe (B5)

## Founder dependencies (not agent-doable)
- **Merge the 11 branches** (squash, linear history). Order note: merge **E1
  before E3** (both touch `sign_in_screen.dart`/`widget_test.dart`, different
  regions → auto-merge). **B5's `verify-no-placeholders.sh` supersedes D5's** —
  take B5's on conflict.
- **E1:** provision SMTP (F-13) + allow-list `pawdoc://login-callback` in the
  Supabase Auth redirect URLs.
- **E3:** raise the server-side minimum password to 8 in the Supabase dashboard.
- **E5:** create/finalize RevenueCat products (F-15) for end-to-end purchase.
- **B2:** verify the iOS icon renders in Xcode (no Xcode in this env).
- **E10:** device pass of a real free-tier 402 → paywall.
- **B5 `--strict` (launch gate):** fill the legal entity/address/effective date
  (attorney), real store URLs, and App Review demo creds before public launch.

## Updated readiness (honest, evidence-based)
- **Engineering-for-beta:** ~**78%** (was ~40% pre-Sprint-1). The product
  lifecycle (auth reset, billing idempotency, identity hygiene, family RLS) and
  the release surface (icon, permissions, truthful copy) are closed in-repo.
  Remaining engineering is small; the rest is founder infra + merges.
- **Beta-50 (store-distributed):** ~**35%** — gated on founder infra (signing,
  monitoring, domain) + SMTP + store-listing fill + merges.
- **Public launch:** ~**10%** — still dominated by the attorney / E&O external
  critical path (the `--strict` gate now enforces the legal fill).

## Honest GO / NO-GO
**NO-GO for public launch** — by design, and now *measured*: the truthfulness
gate's `--strict` mode stays red until the founder/attorney complete the legal
and store fill, and SMTP/products/signing remain founder infra. **GO for the
engineering scope of Sprint 2** — all 11 findings are closed with reproducible
evidence, the safety path is untouched (emergency override, server-injected
disclaimers, no paywalled emergencies), and nothing was marked done without a
green check or a documented founder gate.
