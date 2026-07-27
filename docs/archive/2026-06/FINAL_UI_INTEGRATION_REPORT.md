# PawDoc — Final UI Integration Report (Release Candidate)

**Date:** 2026-06-13
**Mission:** Final UI Integration + Real-Device Release Candidate
**Outcome:** Integration complete and merged to `main`; RC built and forensically verified.
**Companion docs:** `DEVICE_VALIDATION_APPENDIX.md` (on-device results), `FINAL_RELEASE_VERDICT.md` (go/no-go).

---

## 1. Objective

Produce one definitive release candidate that combines, on a single branch:

1. the hardened engineering `main` (finalization merge train PRs #41–#72),
2. the complete new UI program (the unmerged `ui-translation` branch — bottom-nav
   shell, `paw_ui` kit, redesigned screens, `_v1` illustrations),
3. the locale-fallback fix (PR #74),
4. all safety guarantees (emergency override path, disclaimers, paywall bypass).

Root cause this mission corrects: the new UI had **never been merged to `main`**;
prior device validation ran against `main`'s older UI, and a `main`-built APK
contained none of the new `_v1` assets.

## 2. What shipped

| Item | Value |
|---|---|
| Integration branch | `release/ui-final-integration` |
| Branch base | `main` @ `93e3af8` (includes #74 + #41–#72) |
| Merged source | `origin/ui-translation` @ `d4eb557` (9 commits) |
| Merge commit | `a14686a` |
| PR | #76 → squash-merged to `main` |
| **`main` after merge** | **`6f42763`** |
| Files changed vs base | 49 files (+5373 / −996) |

## 3. Conflict resolution (2 files — new UI AND engineering fixes both kept)

Only two files conflicted; both were resolved by taking the new UI and re-weaving
the finalization logic into it (nothing dropped):

- **`mobile/lib/src/auth/sign_in_screen.dart`** — kept the new `_formSheet` UI;
  preserved **E1** forgot-password entry (`forgot_password_button` → reset dialog),
  **E3** 8-character password rule, and the Apple button gated on platform
  availability.
- **`mobile/lib/src/family/family_settings_screen.dart`** — kept the new UI cards;
  preserved **E9** manual-invite entry (`manual_invite_entry`) and **E12** paywall
  navigation (`PaywallScreen`, not `/onboarding`).

The other overlapping screens (`result_screen`, `emergency_result_screen`,
`home_screen`, `pets_list_screen`, router, pubspec) auto-merged cleanly from
`ui-translation`. The emergency screen retains all safety elements
(`emergencyTitle`, `emergency_find_vet`, telehealth deep link, `emergencyDisclaimer`,
`emergencyAcknowledge`, and the "never paywalled" bypass).

## 4. Tests updated to the new UI (assertions NOT weakened)

The new UI rewrote the symptom and sign-in screens, so two test files were updated
to assert against the new widgets — while keeping every safety assertion intact:

- **`test/symptom_text_screen_test.dart`** — the Continue control is now a
  `PawPrimaryButton` (was `AppButton`). The four **E16** assertions are unchanged
  in meaning: a short emergency phrase (`choking`) is NOT length-gated, a 12-char
  emergency phrase is allowed, short non-emergency text (<12) IS gated, and a 12+
  char normal description is allowed. The screen still implements `minChars = 12`
  with an emergency-keyword bypass (`onPressed: tooShort ? null : …`).
- **`test/widget_test.dart`** — the new sign-in form lives in a taller
  `SingleChildScrollView`; the forgot-password test now `ensureVisible`s the entry
  before tapping. The reset dialog (`reset_email_field`, `reset_send_button`) is
  unchanged.

## 5. Local validation (all green)

| Check | Result |
|---|---|
| `flutter analyze` | clean — No issues found |
| `flutter test` | **217 passed, 1 skipped, 0 failed** |
| `ruff check` (ai-service) | clean |
| `pytest -q` (ai-service) | **186 passed** |
| `node --test` (edge `_shared`) | **103 passed, 0 failed** (incl. SSRF + rate-limit guards) |
| `scripts/test-rls.sh` | **PASS** — RLS isolation + family invites + deletion cascade |
| `flutter build apk --release` | 125.1 MB |
| `flutter build appbundle --release` | 105.8 MB |

## 6. Asset packaging — forensic proof (the prior root cause)

The earlier failure was that `main`-built artifacts lacked the new illustrations.
Verified directly inside the built APK:

- **29 `_v1` illustrations** bundled under `assets/flutter_assets/assets/illustrations/…`
- **11 motion files** (`.json` / `.riv`) bundled under `assets/flutter_assets/assets/motion/…`
- All asset directories are registered in `pubspec.yaml`; every illustration const
  that screens reference resolves to a real on-disk file.

Note (non-blocking): a few illustration consts in `app_assets.dart` (e.g.
`resultEmergencySupport`, `petsNone`, `offlineCompanion`) are defined but unused —
this is pre-existing on `ui-translation` (verified against `origin/ui-translation`),
not introduced by the merge, and packages harmlessly. Two consts (`splashLogo`,
`sysOffline`) point at files not present, but both are dead (unreferenced); native
splash is color-only, so there is no runtime missing-asset error.

## 7. CI and merge

PR #76 — **all 6 required checks passed**: gitleaks, ShellCheck, AI ruff+pytest,
Edge node tests, no-placeholders/overclaims, and Flutter analyze+test+build
(19m18s for the cold APK + AAB build). Squash-merged to `main` under
founder-authorized admin (clears the review-required gate; CI passed on its own
merit; linear history preserved).

## 8. Release candidate

- Built from **`main` @ `6f42763`** via Doppler (`pawdoc`/`dev`) with
  `--dart-define=SUPABASE_URL/SUPABASE_ANON_KEY`.
- APK **sha256 `d49504ef67c71d9cac50f785e2f93390f1954cf9b79566816018575e132aead1`**, 125.1 MB.
- Forensically re-verified: 29 `_v1` illustrations + 11 motion files bundled.

**Important:** this RC is built with the **dev** secret set (only Supabase URL/key;
AI-provider, OneSignal, RevenueCat, Sentry keys are absent and degrade gracefully).
It is the headless-testable artifact. The **production** RC — built by the founder
with all keys and the release signing key — is a different artifact and must be the
one submitted to the store. See `FINAL_RELEASE_VERDICT.md` for the implications
(notably full AI analysis and the OneSignal crash-on-exit, both config-dependent).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
