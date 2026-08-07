# PawDoc — UI Implementation Roadmap

**Status:** ✅ Phase 0 · ✅ A–Q — **18 of 18 complete (100%)**. Visual migration of the app-wide system is done; per-screen mockup parity is tracked in the final report.
**Branch:** one per phase; PRs #94 (Phase 0), #95 (A–F), current `ui-impl-phase-g-health`.
**Inputs:** `new-interface/` (57 mockups) · `UI_ASSET_SPECIFICATION.md` · `UI_SAFETY_CONTRACT_REVIEW.md` · `UI_ASSET_PROMPT_LIBRARY.html` · `CLAUDE.md`
**Working agreement:** one phase per PR, validate, report, **stop for approval** before the next.

---

## 0. Executive Summary

### 0.1 What this migration actually is

Not a re-skin. The mockups describe a different **visual system** from the one shipping today:

| | Shipping app | Mockups (System B) |
|---|---|---|
| Background | `ink900` `#0E1413` (near-black teal) | Pure black `#000000`, cards `#0B0F0B` |
| Primary accent | Teal `#00897B` | **Lime / chartreuse `#A3E635` → `#BEF264`** |
| Illustration layer | None (widget-drawn) | Photoreal pets, 3D glassy premium art, neon doodles, HUD |
| Icons | Material `Icons.*` | ~285-glyph system, 14 families |

And the mockups are **two** systems, not one — `000`/`002`–`009` (onboarding) use navy `#050B14` with emerald + heavy cyan; the other 48 use black + lime. Assets are not interchangeable between them (spec §1.3).

### 0.2 The constraint that shapes everything

`UI_SAFETY_CONTRACT_REVIEW.md` found **24 violations across 19 of the 57 mockups** — 9 CRITICAL. The designs show confidence percentages, differential probabilities, named conditions ("Skin Infection"), all-clear headlines ("No signs of a serious condition"), and AI triage placed on the emergency surface. Each breaks a rule in `CLAUDE.md` that exists because **a false negative is the #1 business risk**.

**Therefore: the mockups are not the specification. The mockups plus the safety review are.** Where they disagree, the review wins, and the review supplies layout-preserving replacement copy for every case. Four mockups (`007-onboarding`, `ai_transparency`, `symptom_selection`, `prepare_for_vet_visit`) already demonstrate the compliant voice and are the reference standard.

This produces the roadmap's single most important sequencing rule:

> **A screen's safety copy is corrected in the same phase that re-skins it — never later.**
> We must not ship an intermediate build that is prettier *and* contract-breaking.

### 0.3 Honest fidelity ceiling

The brief targets ~99% visual accuracy. Achievable on layout, spacing, type, colour, elevation and motion. **Not** achievable — and deliberately not attempted — on:

1. **19 screens whose content violates the safety contract.** Pixel-matching them is a defect. Corrected copy is layout-preserving, so geometric fidelity holds; the words differ.
2. **~450 asset files that do not exist.** See §2. Screens using them fall back via `AppImage`.
3. **The core icon set.** Lucide is what the spec names (§6.9), but Lucide glyphs are not pixel-identical to the mockups' bespoke drawings.

Realistic target: **~90–93% overall**, ~97%+ on the screens whose assets fully landed, with every deviation catalogued in the final report.

---

## 1. Phase 0 — Asset Preparation (COMPLETE)

**Commit:** `d17f02a` · 304 files · analyze clean · 373 tests passing (was 372 + 1 failing).

### 1.1 What was found

The stated premise was that asset generation was complete. It was not. 110 PNGs existed, saved under the specification's *unexpanded filename placeholders* — `ic-symptom-<name>.svg.png`, `mem-buddy-{01..24}@3x.webp.png`, `bdg-verified-{lime,blue}@3x.png.png` — where each file is a **contact sheet holding the whole set**. Nothing was addressable by the name the implementation expects, and nothing was declared in `pubspec.yaml`, so none of it reached the bundle.

### 1.2 What was done

291 individually-named production files, via `mobile/tool/asset_pipeline/`:

- **Slicing.** Icon plates have gutters → recursive projection-profile splitting (19/19 families sliced exactly to their specified counts). Photo mosaics are edge-to-edge → explicit grids; two are unevenly divided and use measured seam fractions.
- **Backdrop removal, four modes.** A single white key is wrong for most of the set — it erases the white cloud *inside* a weather icon and the white pictogram *inside* a first-aid tile. `flood` removes only white connected to the border; `key` preserves hue for coloured outline glyphs (whose enclosed white is background, not fill); `white` is used for monochrome line art, whose interiors *should* drop out so the glyph stays tintable; `dark` un-composites neon art off black.
- **Premultiplied resizing.** Cut-outs carry garbage colour beneath `alpha=0`; a naive downscale samples it into a coloured halo.
- **Defect repair.** Four plates had the transparency checkerboard rendered as opaque pixels; the memory grid had `01`–`24` burned into every tile (removed with an asymmetric inset — row 2's labels sit lower than the rest).
- **Size policy.** Art drawn at 96 pt had been emitted at 1024–1536 px. Capped by intended use: 44 MB → **12 MB**.

### 1.3 Guard rail

`test/ui_assets_test.dart` fails CI if any referenced asset is missing from disk, unreachable through `pubspec.yaml`, carries a placeholder name, if the 150 MB plate source ever enters the bundle, or if an icon family's count drifts from its specified inventory. `UiAssets` (`lib/src/theme/ui_assets.dart`) is **generated** from disk by `tool/gen_ui_assets.dart` — a renamed asset becomes a compile error, not a runtime grey box.

---

## 2. Asset Reality — what exists, what does not

**291 of ≈560 specified files (52%).** Reusable coverage is better than that number suggests, because the missing files cluster in two places.

### 2.1 Landed and verified (usable now)

| Family | Count | Notes |
|---|---|---|
| Symptom pictograms | 24 | Complete, spec order verified glyph-by-glyph |
| Anatomy / breed-care / records / vitals / bring / benefit | 55 | Monochrome, tintable |
| Vaccines / first-aid / medication / weather-3D / notifications / actions | 42 | Multicolour tiles |
| Achievement badges + frames | 21 | 6 unlocked + 6 locked + padlock + 2 hex frames |
| Pet cast photography | 16 | Buddy / Luna / Milo / Coco, consistent casting |
| Memory library | 24 | Labels cropped out |
| Human avatars | 17 | Synthetic, non-identifiable |
| Premium 3D | 13 | The glassy-green set, self-contained |
| Emergency artwork | 12 | Incl. 3 clinic exteriors |
| Onboarding heroes + glyphs | 14 | System A |
| Brand, AI, maps, community, breeds, doodles, infographics | 53 | |

### 2.2 Gaps — carried into the phases that need them

| # | Gap | Impact | Handling |
|---|---|---|---|
| G-1 | **Zero SVG.** ~285 glyphs specified `SVG` + `currentColor`; only raster produced | Emergency red re-skin would need a duplicate file set (spec §1.4.4) | **Resolved by design.** Monochrome families ship as black-on-transparent PNG and are tinted at runtime via `ColorFiltered` — functionally equivalent to `currentColor`. Core + nav come from Lucide (true vectors). |
| G-2 | **ICN-801 core set** (~140 glyphs, all 57 screens) generated as 1 generic vet glyph | Would block every screen | **Resolved.** `lucide_icons_flutter`, exactly as spec §6.9 directs ("author, do not generate … base the set on Lucide"). |
| G-3 | **ICN-810 nav set** (11 glyphs) generated as 3 generic pairs | Blocks nav | **Resolved.** Lucide. |
| G-4 | `INF-504` size-reference — checkerboard baked *through* the silhouettes | 1 decorative infographic on `breed_detail` | Regenerate. `AppImage` fallback until then. |
| G-5 | `CMN-1403` reaction chips — 3 chips as one overlapping cluster | Community reactions | Render as 3 Lucide glyphs with brand tints; regenerate later. |
| G-6 | `BRE-1301` cat/rabbit/bird category tiles are golden retrievers | Encyclopedia category row | Regenerate 3 tiles; dog/reptile/all are correct. |
| G-7 | `AVT` map/group avatars — wrong subjects (a path, a graduation cap) | `nearby_pet_owners` | Reuse `avt-community-*`; regenerate later. |
| G-8 | `onb-hero-puppy-kitten-splash` is a blue paw app icon | 1 onboarding hero | Reuse `onb-hero-puppy-kitten-seated`. |
| G-9 | `onb-glyph-cross` missing from its plate | 1 onboarding glyph | Lucide `plus`/`cross` tinted cyan. |
| G-10 | **`TPB-1701`–`1703` trademarks** (Google "G", Visa/MC/Amex, Apple/Google Pay, RevenueCat) | Sign-in + paywall | ⛔ **Must never be AI-generated** (spec §1.7). Source from official brand kits — founder action. Google "G" already ships correctly via `google_sign_in`. |

> **None of G-1…G-9 blocks a phase.** Every one degrades through `AppImage`'s themed fallback, which is exactly why that widget exists.

---

## 3. Cross-Cutting Strategy

### 3.1 Design system — how the palette flips without a big bang

`AppColors` / `PawPalette` are already the single source of truth; **no screen hardcodes a colour**. The migration therefore happens inside `design_tokens.dart`, not across 29 screens.

- Add the System B ramp (`lime500 #A3E635`, `lime400 #BEF264`, `carbon900 #000000`, `carbon850 #0B0F0B`) alongside the existing teal ramp.
- Add the System A ramp (`navy #050B14`, `emerald #22C55E`, `cyan #22D3EE`) scoped to onboarding.
- Introduce `PawSurface.systemA` / `.systemB` so a subtree declares which system it belongs to.
- **Semantic status colours do not move.** `emergencyLight #C62828`, `monitorLight #FFB300`, `actionBookVisit`, `actionWatch` are contract-bearing — the action ladder's colour coding is safety semantics, not decoration. Lime is a *brand* accent and must never be used to signal a triage outcome.

### 3.2 Icons — one adapter, two sources

`PawIcon` wraps: Lucide (core + nav) and the bespoke PNG families (medical). One call site shape, so the emergency red colourway is a `color:` argument, never a second asset set:

```dart
PawIcon.core(LucideIcons.stethoscope, color: c)   // vector, currentColor
PawIcon.symptom('itching', color: c)              // tinted monochrome PNG
PawIcon.tile(UiAssets.vaccine('rabies'))          // multicolour, untinted
```

### 3.3 Widget reuse — what stays, what changes, what dies

| Widget | Fate | Why |
|---|---|---|
| `AppImage` | **Keep, unchanged** | The fallback mechanism that makes incremental merging safe |
| `AppColors` / `AppType` / `AppSpace` | **Extend** | Add ramps; never fork |
| `PawScaffold`, `PawBackground` | **Extend** | Gain a `surface:` system selector |
| `PawCard`, `PawPrimaryButton`, `PawSecondaryButton`, `PawFeatureRow`, `PawCheck` | **Restyle in place** | Same API, new skin — every consumer inherits it |
| `RootShell` | **Rewrite** (Phase C) | Nav bar is structurally different |
| `AppMotionAsset`, `motion.dart` | **Keep** | Reduce-motion plumbing is already correct and safety-tested |
| `LivingPetAvatar`, `PetDisplay` | **Restyle** | Gain the photoreal cast |
| `_PawDecorPainter` | **Replace** | Hand-painted decor superseded by the doodle assets |
| New: `PawIcon`, `PawStatCard`, `PawChip`, `PawSectionHeader`, `PawHeroBanner`, `PawTile` | **Add** (Phase B) | The repeated primitives across all 57 mockups |

**Rule:** no screen phase may introduce a bespoke widget that a later screen will also need. If it repeats, it belongs in Phase B and Phase B gets amended first.

### 3.4 Navigation

Today: `RootShell` = Home · Pets · Assistant · Health · Settings. Emergency is **not** a tab; it is reached from a home-screen red button and from the analysis emergency override.

The mockups' Variant B places **Premium** in the slot Variant A gives to Emergencies, across 9 screens. That is violation **V-24 / conflict C-7** and touches `CLAUDE.md`'s "NEVER paywall / free-tier-block a GET_HELP_NOW result".

**Decision on record (owner, this session): keep Emergency in the navigation; move Premium.**

```
[Home]  [Health]  [ ＋ ]  [Pets]  [Emergency]
                                   └── permanent, on every screen, never displaced
Premium entry points: Account row · header crown affordance · contextual upsell at quota limits
```

This is *stronger* than today (Emergency becomes permanently reachable rather than home-only) and preserves the deep-link table: `/`, `/pets`, `/history`, `/family`, `/invite/:token`, `/r/:code` are unchanged, so nothing using `context.go/push` breaks. The Assistant moves from a tab to the `＋` action sheet alongside photo/text capture, matching the mockups' central-FAB pattern.

### 3.5 Animation

`flutter_animate`, `animations`, `lottie`, `rive` are already in place, as is the reduce-motion pathway. Migration is additive:

- Motion tokens (`AppMotion.fast/base/slow`, standard curves) extend `design_tokens.dart`.
- Shared-axis transitions for tab changes; container-transform for card→detail.
- The scan-ring / HUD assets animate by rotation + opacity, not by video.
- **`no_motion_on_safety_surfaces_test.dart` stays green throughout.** The emergency surfaces render zero motion widgets — that is a test, not a preference.

### 3.6 Responsive

Preserve `AppSpace.maxContentWidth = 480` centring. All new layouts use `LayoutBuilder`/`Flexible`, never fixed pixel heights on text containers. Every phase's acceptance criteria include a 320 dp-wide check (smallest supported) and a 200% text-scale check.

### 3.7 Accessibility

- **Contrast, measured (not assumed):** lime `#A3E635` on black is **13.93:1** and on card `#0B0F0B` **12.81:1** — both clear AA text comfortably. `#BEF264` on black is 16.07:1. System A is fine too: emerald `#22C55E` on navy 8.66:1, cyan `#22D3EE` on navy 10.92:1.
- **Lime cannot be used for text in the light theme.** `#A3E635` on white is **1.51:1** — a hard fail. Even `#65A30D` reaches only **3.09:1** (large/UI only, *not* body text). The light theme therefore uses **`lime700 #4D7C0F`** — 4.99:1 on white and 4.75:1 on the app's `#F7FAF9` surface. `#A3E635` remains available in the light theme for fills and large decorative marks only, never for text or small UI.
- Status colours re-verified: `emergencyLight #C62828` on white 5.62:1, `emergencyDark #FF5A52` on black 6.84:1 — both AA text.
- Every new pairing is checked against WCAG AA (4.5:1 text, 3:1 large/UI) by `design_tokens_test.dart` in Phase A.
- Touch targets ≥ 48×48 dp, enforced in widget tests for the nav and action ladder.
- Decorative illustrations pass `semanticLabel: null` (already `AppImage`'s contract); informational ones get labels.
- Icon-only buttons get `tooltip` + semantic labels.

### 3.8 Localization

`flutter_localizations` + `lib/l10n/app_{en,de}.arb` (EN fallback for other locales — PR #74). **No new user-facing string may be hardcoded.** Every copy change from the safety review lands in both ARBs in the same commit; `l10n_test.dart` and `emergency_l10n_test.dart` gate this. Layouts are verified against German, which runs ~30% longer than English.

### 3.9 Safety contract — the non-negotiables

Mapped from `UI_SAFETY_CONTRACT_REVIEW.md` §5 into the phases that touch those screens:

| Wave | Findings | Lands in |
|---|---|---|
| **S0** — structural, before any build | V-16, V-17, V-24 | **Phase C** (nav) and **Phase F** (emergency surfaces) |
| **S1** — CRITICAL, false-negative paths | V-01–V-06, V-09, V-10, V-11 | **Phase E** (triage results, home), **Phase I** (assistant) |
| **S2** — HIGH | V-07, V-08, V-12–V-15, V-19, V-20 | Phases E, G, K, N, P |
| **S3** — MEDIUM | V-18, V-21–V-23, §4.1, §4.2 | Phases G, I, O |
| **S4** — Health Score decision, typos, l10n audit | §3.4, §4.3, §4.4 | Phase Q |

Permanently enforced, every phase:

- `confidence` is **never** rendered. No percentage may imply certainty.
- **No condition is ever named** in AI output. Describe the observation, not the cause.
- **No "normal", no all-clear, no "do nothing" rung.** Every output terminates with an action *and* a timeframe.
- Emergency keyword override runs **before** any AI call; the triplicated keyword lists stay parity-tested (`emergency_keywords_parity_test.dart`).
- Disclaimers stay **API-injected** — the UI only gates on `disclaimer_required`. `scripts/verify-disclaimers.sh` must pass.

### 3.10 Emergency flow — frozen

`EmergencyHelpScreen` and `EmergencyResultScreen` receive **colour-token updates only**. No new content. No monetization, affiliates, upsells, AI-driven content, or meter. The red path stays offline-capable and model-free.

Two mockup elements are **rejected**, per the review:
- `emergency_hub`'s "AI Triage" quick action (V-16) → replaced with an **offline** Emergency Checklist tile.
- `emergency_hub`'s "Heat Alert" promo strip (V-16/C-6) → removed.
- `first_aid_guide`'s "Start AI Triage" hero + "AI Powered" badge (V-17) → reframed as an offline "Browse by symptom" (the asset was already rewritten `AI-306` → `EMG-609`).

Guarded by `no_motion_on_safety_surfaces_test.dart`, `emergency_router_test.dart`, `paywall_policy_test.dart`, `invariant_no_dead_ends_test.dart`.

### 3.11 Premium flow — behaviour frozen, skin only

`paywall_policy` and the server-side emergency bypass are untouched. Purchase, restore, entitlement and quota logic are not in scope for any UI phase. Only presentation changes. `paywall_policy_test.dart`, `paywall_pricing_test.dart`, `pdf_entitlement_test.dart`, `purchase_error_message_test.dart` must stay green.

**GET_HELP_NOW is never paywalled** — enforced server-side *and* client-side, and re-verified on device in Phase Q.

### 3.12 Regression prevention

1. **Token-first.** Palette changes land in one file; screens inherit. Minimises diff surface per screen.
2. **API-stable widgets.** `PawCard` etc. keep their signatures, so restyling cannot break call sites.
3. **`AppImage` everywhere.** A missing asset degrades; it never crashes or shows a broken box.
4. **Generated asset constants.** Renames become compile errors.
5. **Golden-free.** Deliberately *no* golden tests — they would fail on every intentional pixel change and train us to blind-accept. Visual verification is mockup-diff (Phase 4) plus device pass (Phase 5); behaviour is guarded by the existing 373 tests.
6. **The safety suite is the tripwire.** Any phase that reddens `emergency_*`, `paywall_policy`, `no_motion_on_safety_surfaces`, `invariant_no_dead_ends`, `verify-disclaimers.sh` or `emergency_keywords_parity` **stops immediately**.

### 3.13 CI gate — after every phase

`.github/workflows/ci.yml` runs 7 jobs: ai-service ruff+pytest · shellcheck · gitleaks · RLS+cascade · Edge node tests · no-placeholders · **Flutter analyze + test + build**.

Per-phase local gate before push:

```bash
cd mobile && flutter analyze && flutter test          # must be 0 failures
./scripts/verify-disclaimers.sh
./scripts/verify-no-placeholders.sh
node --test supabase/functions/_shared/*.test.mjs     # only if shared code touched
```

Push → wait for green → **stop for approval**. Red CI halts the roadmap until fixed.

---

## 4. Phase Plan

Ordering rationale: **foundation → chrome → the safety-critical core loop → everything else → onboarding → hardening.** The triage loop comes early because it carries all 9 CRITICAL findings and is the product's reason to exist. Onboarding is late because System A is a self-contained second palette with no downstream dependants. Community and Encyclopedia are last of the feature phases — lowest risk, lowest traffic.

Dependencies are strictly linear A → B → C, then D–P may be reordered on request; Q is always last.

---

### ✅ Phase A — Design system (System A + B ramps)

| | |
|---|---|
| **Objective** | Both palettes, type scale, radii, elevation, motion tokens live in `design_tokens.dart`. Zero screen changes. |
| **Screens** | None (theme only) |
| **Widgets** | `AppColors`, `AppType`, `AppSpace`, new `AppMotion`, `AppRadius`, `AppElevation`; `app_theme.dart` |
| **Assets** | None |
| **Risks** | A palette flip applied globally would restyle 29 screens at once and swamp review. **Mitigation:** ramps are *added*; `PawSurface` still defaults to the current system until Phase C. |
| **Rollback** | Revert one file. No screen depends on the new tokens yet. |
| **Tests** | New `design_tokens_test.dart`: WCAG AA contrast for every text/background pairing in both systems and both themes; semantic status colours unchanged (pinned by literal value). |
| **Acceptance** | `flutter analyze` clean; 373 tests still pass; every new pairing ≥ 4.5:1 (or ≥ 3:1 large/UI); `emergencyLight/monitorLight/actionBookVisit/actionWatch` byte-identical to today. |

---

### ✅ Phase B — Shared widget library

| | |
|---|---|
| **Objective** | Every primitive repeated across the 57 mockups exists once, styled, tested. |
| **Screens** | None (a `/dev/gallery` debug route renders all primitives) |
| **Widgets** | New `PawIcon`, `PawChip`, `PawStatCard`, `PawSectionHeader`, `PawHeroBanner`, `PawTile`, `PawProgressRing`, `PawEmptyState`. Restyle `PawCard`, `PawPrimaryButton`, `PawSecondaryButton`, `PawFeatureRow`, `PawCheck`. |
| **Assets** | Lucide; `UiAssets` icon families |
| **Risks** | Restyling shared widgets changes all 29 existing screens at once. **Mitigation:** signatures unchanged; the full 373-test suite is the regression net; the diff is reviewable because it is one file per widget. |
| **Rollback** | Per-widget revert; each is an independent commit within the phase. |
| **Tests** | `paw_ui_test.dart` per primitive: renders, respects `PawSurface`, honours reduce-motion, touch target ≥ 48 dp, tint applies to `PawIcon.symptom`. |
| **Acceptance** | Gallery route renders all primitives in both systems, both themes, at 320 dp and 200% text scale, with no overflow. Existing suite green. |

---

### ✅ Phase C — Navigation shell + safety wave S0

| | |
|---|---|
| **Objective** | New bottom nav with **Emergency permanently present**; central `＋` action sheet; shared-axis transitions. |
| **Screens** | Chrome on all tabbed screens (9 mockups show the nav) |
| **Widgets** | `RootShell` (rewrite), new `PawNavBar`, `PawActionSheet` |
| **Assets** | Lucide nav glyphs (G-3) |
| **Safety** | **V-24 / C-7 resolved** — Premium never occupies the Emergency slot. |
| **Risks** | Highest structural risk in the roadmap. Tab reorder could break deep links or the auth redirect. **Mitigation:** the go_router table is *not* touched — `RootShell` remains a local `IndexedStack` mounted only at `/`. Assistant moves from tab to `＋` sheet; its route stays. |
| **Rollback** | `RootShell` is one file and self-contained; revert restores the 5-tab shell exactly. |
| **Tests** | Extend `router_redirect_test.dart`; new `root_shell_test.dart`: Emergency destination present on every tab, reachable in ≤ 1 tap from all 5 tabs, survives cold start **offline**; `invariant_no_dead_ends_test.dart` green. |
| **Acceptance** | All deep links resolve unchanged; Emergency reachable offline from every tab; nav targets ≥ 48 dp; labels localised EN+DE. |

---

### ✅ Phase D — Home (`010-home-page`) + safety wave S1a

| | |
|---|---|
| **Objective** | The most-seen screen, on the new system. |
| **Screens** | `010-home-page` |
| **Widgets** | `home_screen.dart`, `PawStatCard`, `PawHeroBanner`, `LivingPetAvatar` |
| **Assets** | `pet-buddy-hero-cutout`, `pet-buddy-avatar`, `ic-vital-*`, `prm-3d-crown-paw`, weather 3D set |
| **Safety** | **V-09 CRITICAL** — home renders an all-clear ("No health issues detected"). Replaced with an observation + timeframe + action, per review §1 V-09. |
| **Risks** | The offline cold-start path previously shipped a bug where Emergency was unreachable (device-found, fixed). **Mitigation:** `home_offline_test.dart` must stay green; offline is an explicit device check. |
| **Rollback** | Single screen revert. |
| **Tests** | `home_test.dart`, `home_offline_test.dart`, `home_hero_last_check_test.dart`, `first_check_toast_test.dart` — all must pass unmodified except where copy assertions change (updated in the same commit). |
| **Acceptance** | No all-clear string anywhere; the red Emergency affordance is present offline; matches mockup within tolerance on spacing/type/colour. |

---

### ✅ Phase E — AI triage flow + safety wave S1b (highest risk)

| | |
|---|---|
| **Objective** | The full capture → analysis → result loop. |
| **Screens** | `ai_health_check_start`, `photo_analysis_upload`, `symptom_selection`, `ai_analysis_loading`, `ai_analysis_result_low_risk`, `ai_analysis_result_monitor`, `ai_analysis_result_emergency`, `ai_transparency` |
| **Widgets** | `camera_screen`, `symptom_text_screen`, `loading_screen`, `result_screen`, `emergency_result_screen` |
| **Assets** | 24 symptom pictograms, `ai-loading-scan-ring`, `ai-scan-hud-dog`, `inf-photoquality-*`, `emg-dog-lesion-clinical`, `ill-doodle-*` |
| **Safety** | **6 of the 9 CRITICAL findings land here.** V-01 confidence chip → removed. V-02 differential bars → removed (review §3.5 supplies the qualitative alternative). V-03 "No signs of a serious condition" → observation + timeframe. V-04 risk chip carrying a confidence value → removed. V-05 named condition on the emergency result → observation only. V-06 diagnostic bullet list → removed. Plus V-07 "for faster diagnosis" copy. |
| **Risks** | **The single most dangerous phase in the roadmap.** Any regression here is a false-negative path. **Mitigation:** copy corrections land *before* the re-skin within the phase, as separate commits, each with its own test; the emergency result screen gets colour tokens only. |
| **Rollback** | Per-screen commits; the emergency result screen is last and independently revertible. |
| **Tests** | `result_test.dart`, `analysis_result_test.dart`, `analysis_integration_test.dart`, `emergency_router_test.dart`, `emergency_keywords_parity_test.dart`, `no_motion_on_safety_surfaces_test.dart`, `paywall_policy_test.dart`. **New** `safety_copy_test.dart`: asserts no rendered result surface contains a `%`-with-certainty, a condition name from a denylist, or an all-clear phrase, in EN **and** DE. |
| **Acceptance** | `verify-disclaimers.sh` passes; zero confidence/differential values render; no condition named; every result terminates with an action **and** a timeframe; emergency result unchanged but for colour; GET_HELP_NOW not paywalled at 0 quota. |

---

### ✅ Phase F — Emergency & first aid (S0 completion)

| | |
|---|---|
| **Objective** | Re-skin the red path without adding anything to it. |
| **Screens** | `emergency_hub`, `first_aid_guide` |
| **Widgets** | `emergency_help_screen`, `first_aid.dart`, `vet_finder` |
| **Assets** | `emg-*` (12), `ic-fa-*` (8), `emg-clinic-exterior-*` |
| **Safety** | **V-16** AI Triage tile → offline Emergency Checklist. **V-16/C-6** Heat Alert promo strip → removed. **V-17** "Start AI Triage" hero + "AI Powered" badge → offline "Browse by symptom". |
| **Risks** | Rule 4 is absolute; the mockups violate it three ways. **Mitigation:** the rejected elements are simply not built. Reviewer checklist: no model call, no network dependency, no monetization on these screens. |
| **Rollback** | Two screens, independently revertible. |
| **Tests** | `no_motion_on_safety_surfaces_test.dart`, `emergency_l10n_test.dart`, `emergency_router_test.dart`. **New**: emergency surfaces make zero network calls and render offline from cold start. |
| **Acceptance** | Airplane-mode device pass: hub + first aid fully functional; no AI affordance present; disclaimer + acknowledgment gate intact. |

---

### ✅ Phase G — Health records

**Screens:** `health_timeline`, `add_health_record`, `vaccination_manager`, `medication_tracker`, `weight_tracking`, `pdf_health_report_preview`, `pet_statistics`, `prepare_for_vet_visit`
**Widgets:** `history_timeline_screen`, `health_event_form_screen`, `vet_visit_prep_screen`, `export/`
**Assets:** `ic-rec-*` (8), `ic-vax-*` (8), `ic-med-*` (4), `ic-vital-*` (10), `ic-anat-*` (12), `ic-bring-*` (5)
**Note:** `prepare_for_vet_visit` is one of the four **compliant reference screens** — it frames everything as preparation for a professional, never as an assessment. Re-skin it; do not "fix" its copy.
**Safety:** V-08 Health Score as clinical verdict · V-10 **CRITICAL** timeline entry asserting a cause · V-19 "Conditions 0 — None — Great!" · V-20 baseline all-clear · V-21 statistics all-clear · **V-22** PDF cannot distinguish AI output from vet records (needs a template change + provenance markers, review §4.2)
**Risks:** V-22 touches the PDF export template, not just UI. **Rollback:** per-screen. **Tests:** `health_test.dart`, `record_phase4_test.dart`, `export_test.dart`, `journal_test.dart`, `pdf_entitlement_test.dart`, `health_event_validation_test.dart`.
**Acceptance:** every AI-derived row carries a provenance marker; no all-clear; PDF visually separates AI observations from vet-entered records.

---

### ✅ Phase H — Pets & profile

**Screens:** `pet_profile`, `edit_pet`, `manage_multiple_pets`, `add_memory` entry points
**Widgets:** `pets_list_screen`, `pet_form_screen`, `pet_photo_crop_screen`, `PetDisplay`, `LivingPetAvatar`
**Assets:** pet cast (16), `pet-species-*` (5), `ic-species-*-badge` (3)
**Risks:** Pet-photo upload + crop is working, device-validated code — presentation only. Cross-account bleed-through was a real past bug; `account_switch_isolation_test.dart` and `current_user_id_reactivity_test.dart` must stay green.
**Tests:** `pets_list_test.dart`, `pet_test.dart`, `pet_display_test.dart`, `pet_photo_test.dart`, `species_chip_test.dart`, `living_pet_avatar_test.dart`.
**Acceptance:** species art replaces emoji fallbacks; no user-scoped provider regression.

---

### ✅ Phase I — AI assistant

**Screens:** `ai_assistant_home`, `ai_assistant_chat`, `conversation_history`, `ai_message_actions`
**Widgets:** `assistant_screen`, `chat_controller`, `sse_client`
**Assets:** `ai-assistant-avatar`, `ai-robot-mascot-neon`, `ai-hologram-dog-cat`, `ic-act-*` (8)
**Safety:** **V-11 CRITICAL** assistant names conditions as causes · V-12 suggestion chips presuppose conditions · V-18 conversation title states a condition as fact · **V-23** "AI Vet Assistant" implies a veterinarian
**Risks:** SSE streaming must not regress. **Tests:** `assistant_screen_test.dart`, `chat_controller_test.dart`, `sse_client_test.dart`, `assistant_avatar_test.dart`.
**Acceptance:** no condition named in any assistant surface; the role label never implies a licensed vet; disclaimer present.

---

### ✅ Phase J — Memories

**Screens:** `memories_gallery`, `memory_detail`, `add_memory`, `search_memories`
**Assets:** `mem-buddy-01..24`, `map-memory-location`
**Tests:** `memories_screen_test.dart`, `memory_model_test.dart`. **Acceptance:** free-cap premium sheet behaviour unchanged.

---

### ✅ Phase K — Lifestyle (walks, weather, baseline)

**Screens:** `smart_walks`, `weather_walk_advisor`, `know_your_baseline`
**Assets:** `ic-wx-*` (8), `map-walk-route-live`, `map-route-thumb-*`, achievement badges (21)
**Safety:** V-20 baseline all-clear. **Tests:** `walks_parsing_test.dart`, `walk_scorer_test.dart`, `walk_card_test.dart`.

---

### ✅ Phase L — Encyclopedia

**Screens:** `breed_encyclopedia`, `breed_detail`
**Assets:** `bre-*`, `ic-care-*` (12) · **Gaps G-4, G-6 apply**
**Tests:** `encyclopedia_screen_test.dart`, `breed_catalog_test.dart`.

---

### ✅ Phase M — Community

**Screens:** `community_feed`, `community_post_detail`, `create_post`, `nearby_pet_owners`
**Assets:** `cmn-*`, `avt-*` (17), `map-community-neighbourhood` · **Gaps G-5, G-7 apply**
**Risks:** Play UGC policy requires report & block to remain reachable. **Tests:** `community_screens_test.dart`, `community_models_test.dart` (incl. the report-&-block assertion).

---

### ✅ Phase N — Premium & monetization

**Screens:** `premium_home`, `subscription_plans`, `upgrade_benefits`, `usage_limits`
**Assets:** `prm-3d-*` (13), `ic-benefit-*` (8), `bdg-*`
**Safety:** V-15 capability claims promising identification · V-24 already resolved in Phase C
**Risks:** **Behaviour is frozen** — presentation only. Mixed-currency pricing and raw `PlatformException` were real past bugs. **Tests:** `paywall_policy_test.dart`, `paywall_pricing_test.dart`, `purchase_error_message_test.dart`, `premium_welcome_test.dart`, `pdf_entitlement_test.dart`.
**Acceptance:** GET_HELP_NOW never paywalled (re-verified); no currency mixing; no raw platform errors surfaced.

---

### ✅ Phase O — Account & settings

**Screens:** `profile`, `account_management`, `privacy_security`, `notifications`, `reminder_detail`
**Assets:** `ic-notif-*` (6), `prm-3d-shield-lock`, `bdg-verified-*`
**Safety:** §4.2 provenance markers. **Risks:** account deletion is a live, cascade-tested flow — presentation only.
**Tests:** `account_service_test.dart`, `delete_account_screen_test.dart`, `account_subscription_tile_test.dart`, `account_switch_isolation_test.dart`, `reminders_test.dart`.

---

### ✅ Phase P — Onboarding (System A)

**Screens:** `000`, `002`–`009` (9)
**Assets:** `onb-*` (14) · **Gaps G-8, G-9 apply**
**Safety:** V-13 onboarding assistant names conditions · V-14 "Low urgency" rendered as a finding · V-15 capability claims
**Risks:** Separate palette; first-run is high-visibility. **Note:** `007-onboarding` is the compliant reference — do not "fix" it.
**Tests:** `onboarding_test.dart`, `l10n_test.dart`, `widget_test.dart`.
**Acceptance:** System A palette scoped to onboarding only; no leakage into System B screens.

---

### ✅ Phase Q — Hardening, device validation, final report

**Objective:** close S2/S3/S4, full-matrix device pass, produce `UI_IMPLEMENTATION_FINAL_REPORT.md`.

- Remaining safety findings; §4.3 copy defects; §4.4 localisation audit; §3.4 Health Score decision (owner).
- Full device matrix on the connected Android device (`AYXSUKIVJVPZ7HPZ`): release build, every screen, dark + light, 320 dp, 200% text scale, airplane mode, cold start, rotation, memory/jank profile.
- Regenerate the G-4…G-9 assets if the owner approves.
- Visual diff of every screen against its mockup; catalogue every remaining deviation.

**Acceptance:** all 7 CI jobs green; safety suite green; no CRITICAL or HIGH finding open; final report delivered.

---

## 5. Per-Phase Execution Loop

```
1. Re-read the phase here + the relevant UI_SAFETY_CONTRACT_REVIEW findings
2. Branch:  ui-impl-phase-<X>-<slug>
3. Implement ONLY that phase's scope
4. Safety copy first, then the re-skin (separate commits)
5. flutter analyze && flutter test            → 0 failures
   ./scripts/verify-disclaimers.sh            → PASS
   ./scripts/verify-no-placeholders.sh        → OK
6. Release build → install on device → walk every changed screen
7. Compare against the mockup; fix deviations
8. Commit (Co-Authored-By) → push → PR → wait for CI GREEN
9. Write sub-pr-report/SUBPR_UI_<X>.md
10. STOP for explicit approval
```

**Squash-merge only** — `main` is protected (linear history + review).

---

## 5a. Execution log

| Phase | Commits | Notes |
|---|---|---|
| 0 | `d17f02a` | 291 assets from 110 placeholder-named plates |
| A | `2eac156` | Both ramps + `PawSystem`; light-mode lime corrected to `#4D7C0F` |
| B | `e88a3b9` | 13 primitives; caught a 42dp touch target |
| C | `6e45e39` | Emergency permanent destination (C-7/V-24 resolved) |
| D | `00924e7`, `9d846d9` | Pill grid; `PawCard` migrated all consumers |
| E | `6b5f7da` | `safety_copy_test` tripwire; `PawBackground` follows system |
| F | `4d272e2` | D-1 pinned; third rule-4 violation found in `emergency_hub` |
| G | `76e3ab4` | **App-wide System B `ColorScheme`** — every Material widget migrates at once; V-22 provenance markers in the exported report |
| H | `fb2c6f6` + | Species art wired — `AppAssets.species()` pointed at an **empty** folder, so every chip/avatar had silently fallen back to emoji since M2. Primary CTA + `secondaryContainer` migrated |
| I | `dc84714` | **System B declared at the app root** — pushed routes sit above the shell's scope, so every detail screen was still resolving to `legacy`. Assistant audited clean; V-12/V-23 pinned |
| J–O | `5ecff02` | **Accent palette repointed** — `PawPalette.mint`/`.teal` were used at ~120 sites as "the accent", not as literal colours. Repointing the two constants migrated memories, encyclopedia, walks, reminders, community, premium and account in one change, instead of ~120 edits (many inside `const` constructors). `PawFeatureRow` icon tiles now resolve through `PawTone`. |

| P | `b619336` | System A isolated on onboarding + sign-in; `system_isolation_test` pins the boundary |
| Q | *(this branch)* | Full gate set + device matrix on the Redmi |

**Discovery recorded during G (no stop):** the app-wide theme flip was the
highest-leverage remaining change and is what makes H–P re-skins rather than
rewrites. Screens now inherit System B through *two* agreeing paths — the
Material `ColorScheme` and `PawSystemScope`/`PawTone`.

---

## 6. Open Owner Decisions

| # | Decision | Blocks | Recommendation |
|---|---|---|---|
| D-1 | **C-4 / V-16** — remove the "AI Triage" tile and "Heat Alert" strip from `emergency_hub`? | Phase F | **Remove.** Rule 4 is absolute; the review supplies an offline Emergency Checklist replacement. |
| D-2 | **§3.4 Health Score** — is it a wellness metric or a clinical verdict? | Phases D, G | Keep as an engagement metric, relabel so it cannot read as a verdict, never colour it with triage semantics. |
| D-3 | **Pet-name collisions** (spec §1.4.2) — Luna is a rabbit *and* a retriever; Milo a dark tabby *and* a British Shorthair; Coco a rabbit *and* a poodle | Phases H, M | Both castings exist in the shipped assets. Pick one per name for consistency. |
| D-4 | Regenerate the G-4…G-9 assets? | Phase Q | Yes for G-6 (3 breed tiles, visible); optional for the rest. |
| D-5 | **G-10 trademark marks** — source Visa/MC/Amex/Apple Pay/Google Pay from official brand kits | Phase N | Founder action. Must not be AI-generated. |

---

## 7. Effort & Risk Summary

| Phase | Screens | Risk | Safety findings |
|---|---|---|---|
| A Design system | 0 | Low | — |
| B Widget library | 0 | Medium (touches all) | — |
| C Navigation | chrome | **High** (structural) | V-24 |
| D Home | 1 | Medium | V-09 |
| **E AI triage** | 8 | **Highest** | **V-01–V-07 (6 CRITICAL)** |
| F Emergency | 2 | **High** (rule 4) | V-16, V-17 |
| G Health records | 8 | Medium | V-08, V-10, V-19–V-22 |
| H Pets | 3 | Low | — |
| I Assistant | 4 | Medium | V-11, V-12, V-18, V-23 |
| J Memories | 4 | Low | — |
| K Lifestyle | 3 | Low | V-20 |
| L Encyclopedia | 2 | Low | — |
| M Community | 4 | Low | — |
| N Premium | 4 | Medium (revenue) | V-15 |
| O Account | 5 | Low | §4.2 |
| P Onboarding | 9 | Low | V-13–V-15 |
| Q Hardening | all | Medium | S2/S3/S4 |

**Critical path:** A → B → C → E. Phases G–P are parallelisable across sessions if desired; each still requires its own approval gate.

---

*Roadmap authored against Phase 0 commit `d17f02a`. Every count in §1 and §2 was verified against the files on disk, not taken from the specification.*
