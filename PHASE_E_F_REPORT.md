# PawDoc UI/UX Execution — Cycle 3 Report (Phases E + F)

- **Date:** 2026-06-10
- **Branch:** `ui-cycle-e-f` (off `main` @ `1fff9e6`, i.e. after Cycles 1–2 merged)
- **Source of truth:** `PAWDOC_UI_UX_MASTER_ROADMAP.md` §3.1 (sign-in), §3.3 (home), §8 Phase E/F, §9.E/§9.F, §4.1/§4.2/§4.4
- **Scope rule honored:** UI / theme / asset / motion only. **No auth logic, providers, data logic, AI pipeline, RLS, Edge Functions, routing guards, or purchase logic changed.**

---

## Implemented phases

- **Phase E — Authentication / Sign-in** (make the first frame finished & trustworthy)
- **Phase F — Home / Dashboard Re-rank** (care-first hierarchy; fix the monetization-over-care inversion)

---

## Objectives

**Phase E:** Fill the dead top third with a brand lockup, convert fields to Material 3 filled with floating labels, move auth errors from a bottom snackbar to a calm inline banner, and add an honest trust footer (encryption + Privacy/Terms) — no fabricated claims — while keeping Apple/Supabase auth, the validators, and all keys.

**Phase F:** Re-rank the home so the **pet and the Check action lead** and the billing quota is demoted; move **Logout off the AppBar into the overflow menu** (no accidental sign-out); add a warm, illustrated empty state; and add tasteful, reduce-motion-gated motion (card stagger, avatar breathing) on top of the Phase C skeletons. Providers/data untouched.

---

## Files changed

| File | Change |
|---|---|
| `mobile/lib/src/auth/sign_in_screen.dart` | **E:** `_brandLockup` (`AppImage(logoMark)` + wordmark, fallback paw-disc), reassurance subline, **filled fields** + prefix icons + `TextInputAction`, **inline `_errorBanner`** (replaces snackbar; live-region, dismissible), `AppButton` press-scale on Sign in, **`_trustFooter`** (encryption line + Privacy/Terms via `url_launcher`). Validators, keys (`email_field`/`password_field`/`sign_in_button`/`sign_up_button`/`apple_sign_in_button`), and Apple/Supabase logic unchanged. |
| `mobile/lib/src/home/home_screen.dart` | **F:** new **`_PetHeroCard`** (#1 — avatar via `AppImage`+breathing, name, species·breed, last-check, `AppButton` Check CTA); **`_QuotaStrip`** demoted to the bottom (was the top billing card); breed-insight moved below the pet; **Logout moved into the overflow menu** (`sign_out_button` key now a menu item) + labeled AppBar actions; warm **`_HomeEmptyState`** (`AppImage(emptyHome)` + single Add-pet CTA + positive quota framing); error → `AppErrorView` (retry); skeletons re-ordered to match; `_staggered` card fade-up. Reduce-motion-gated. `_check`/`_logEvent`/`_PetSwitcher`/providers unchanged. |
| `mobile/test/widget_test.dart` | **E:** added trust-footer test (encryption + Privacy/Terms + subline). |
| `mobile/test/home_test.dart` (new) | **F:** warm empty state + logout-not-one-tap (in overflow menu) test, via `petsListProvider`/`connectivityProvider` overrides. |

---

## Acceptance criteria checklist

### Phase E (§3.1 / §9.E)
- [x] `BrandLockup` (`AppImage(AppAssets.logoMark`, fallback paw-disc CustomPaint-equivalent) fills the top third.
- [x] Reassurance subline added ("Calm, vet-informed triage for your pet — in seconds.").
- [x] Email/Password → Material 3 **filled** fields with floating labels (+ teal focus ring via theme).
- [x] `PrivacyTrustFooter` (encryption + Privacy/Terms links) — **no fabricated claims**.
- [x] Auth error → **calm inline banner** above the button (replaces bottom snackbar R07); dismissible + clears on retry.
- [x] In-flight spinner + label; **AppButton** press-scale on the primary CTA.
- [x] Autofill hints kept; **Apple sign-in untouched/working**; AA contrast (filled fields + onSurfaceVariant).
- [x] `analyze`/`test` green (keys + validators preserved — existing tests pass).
- [ ] **MANUAL:** real email + Apple sign-in on device (auth not exercised headless).

### Phase F (§3.3 / §9.F)
- [x] `PetHeroCard` is the **#1** element (avatar + name + species·breed + last-check + Check CTA, name via Phase B helper).
- [x] Quota demoted to a slim `QuotaStrip` at the bottom; breed-insight + journal content kept, moved below the pet.
- [x] **Logout moved out of the AppBar into the overflow menu** (no longer one-tap) — widget-tested; AppBar actions labeled (tooltips); pet switcher kept.
- [x] Warm `HomeEmptyState` (illustration + single Add-pet CTA + positive quota framing) — widget-tested.
- [x] Card stagger-fade + pet-avatar breathing + skeletons; all reduce-motion-gated.
- [x] `analyze`/`test` green; **providers/data logic unchanged** (layout/labels only).
- [ ] **MANUAL:** device visual (hierarchy, breathing, stagger) + reduce-motion sweep.

### Cross-cutting (§8.1)
- [x] analyze clean / 109 tests green. [x] reduce-motion (global test config + gated code). [x] no safety/business-logic diff. [x] light + dark build.

---

## Device validation results

**Status: BLOCKED → MANUAL (founder-side). Not faked.** The device is **disconnected** (`adb devices` empty); earlier it was locked + MIUI-install-restricted. Install + screenshots are founder-side.

**Founder runbook:** build with real Doppler defines, install, and capture: **sign-in** (brand lockup, filled fields, trust footer; trigger a bad login to see the inline error banner), and **home** (pet hero #1, quota at the bottom, Logout only inside ⋮, warm empty state with no pets). Then toggle "Remove animations" and confirm static. (See Cycle 1/2 reports for the exact commands.)

> Note: the Privacy/Terms footer links open `https://pawdoc.app/privacy` and `/terms` — **those pages must be live before launch** (founder content task; see Remaining concerns).

## Screenshots index
`runtime/ui_validation/cycle_ef/` — *(empty; device unavailable — founder to populate).*

## Flutter analyze results
```
$ flutter analyze
No issues found! (ran in 3.3s)
```
## Flutter test results
```
$ flutter test
00:08 +109: All tests passed!
```
New: sign-in trust-footer test + home empty-state/logout-in-menu test (+2 → 109).
## Build results
```
$ flutter build apk --debug --dart-define=…
✓ Built build/app/outputs/flutter-apk/app-debug.apk   (assembleDebug 42.7s)
```
## CI results
Not runnable here (`gh` absent; `main` protected). MANUAL/founder: CI on PR; local gates all green above.

---

## Regressions found / fixed
- None new. The sign-in redesign preserved all keys + validators (existing `widget_test.dart` still passes); the home re-rank kept providers/`_check`/`_logEvent` intact. Full suite green (109, up from 107). The home test required overriding only `petsListProvider`→`[]` and `connectivityProvider`→online (the empty-state path needs no other backend).

---

## Self-audit (roadmap requirement → status)

| # | Requirement | Status | Note |
|---|---|---|---|
| E1 | BrandLockup fills top third | **COMPLETE** | AppImage + paw-disc fallback. |
| E2 | Reassurance subline | **COMPLETE** | §3.1 copy. |
| E3 | Filled fields + floating labels + focus ring | **COMPLETE** | filled + prefix icons; ring via theme. |
| E4 | PrivacyTrustFooter, no fake claims | **COMPLETE** | encryption + Privacy/Terms (links → pawdoc.app). |
| E5 | Inline auth-error banner (not snackbar) | **COMPLETE** | live-region + dismiss. |
| E6 | Button in-flight + press-scale; autofill; Apple untouched | **COMPLETE** | success check-morph deferred (auth redirect replaces the screen — see concerns). |
| F1 | PetHeroCard #1 | **COMPLETE** | avatar+name+breed+last-check+CTA. |
| F2 | Quota demoted; insight/journal below pet | **COMPLETE** | `_QuotaStrip` at bottom. |
| F3 | Logout → menu; AppBar labels | **COMPLETE** | widget-tested. |
| F4 | Warm empty state | **COMPLETE** | illustration fallback + single CTA + positive quota. |
| F5 | Stagger + breathing + skeletons (reduce-motion) | **COMPLETE** | count-up + result-return-highlight deferred (see concerns). |
| F6 | Providers/data unchanged | **COMPLETE** | layout/labels only. |
| — | Device visual | **PARTIAL (MANUAL)** | device disconnected. |

---

## Remaining concerns (surfaced)
1. **Privacy/Terms pages must be live** — the footer links to `https://pawdoc.app/privacy` and `/terms`. The links are correct for the app's domain, but those pages need to exist before launch (founder content). Flagging rather than silently shipping a possible 404.
2. **Sign-in success check-morph deferred** — on success, Supabase auth state changes and the router redirects away, replacing the sign-in screen, so a pre-navigation check-morph has no stable surface. The in-flight spinner+label is in place; the morph is a low-value polish item given the auto-redirect.
3. **Quota count-up + result-return highlight deferred** (§3.3 delight) — count-up on a *remaining* count (3→…) is semantically odd, and the result-return highlight needs return-from-analysis detection (state/route awareness beyond layout). Both are optional delight; core re-rank is complete. Surfaced for your call.
4. **Illustration assets** (logo mark, empty-home) render code fallbacks today (paw-disc / paw icon) — Phase 6 asset generation lights them up with zero code change.
5. **Device validation MANUAL** — device must be reconnected/unlocked (MIUI "Install via USB").
6. **Fonts runtime-fetched** (carried) — bundling `.ttf` is the offline-hardening follow-up.

---

## Recommendation

**Phases E + F are code-complete, lint-clean (0 issues), tested (109 green incl. new sign-in trust-footer + home logout-in-menu tests), and build a debug APK.** The first frame now reads finished and honest; the home leads with the pet and the Check action, with the quota demoted and logout safely tucked into the menu. No auth/business/data logic was touched.

Outstanding items are founder-side: **on-device visual + auth/Apple sign-in + reduce-motion sweep**, **the Privacy/Terms pages going live**, and **PR/CI → squash-merge** (protected `main`, no `gh` here).

Branch `ui-cycle-e-f` is pushed and ready. **STOP — say "merge E+F" to squash-merge (same flow as A–D), then I'll begin Cycle 4 (Phases G + H).** Note: **Phase H is the safety-critical analysis/result/EMERGENCY phase** — it carries the roadmap's extra-review gate (server-forced disclaimer, emergency bypass, ack gate, confidence<0.60 path all preserved and re-verified).
