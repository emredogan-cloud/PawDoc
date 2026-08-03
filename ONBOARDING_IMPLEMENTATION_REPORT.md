# PawDoc — Onboarding Implementation Report

**Date:** 2026-08-03 · **Commit:** `d0fe94b` · **Branch:** `ui-impl-phase-p-onboarding`
**Scope:** the onboarding flow only. No other screen was migrated in this pass.

---

## 1. Implemented screens

Eight pages, rebuilt against mockups `002`–`009`. Previously three.

| # | Page | Mockup | Key |
|---|---|---|---|
| 1 | Value hook — *"Every pet deserves calm, informed care."* | `002` | `onb_get_started` |
| 2 | AI insights — sample health check | `003` | `onb_next_emergency` |
| 3 | Emergency guidance — comparison cards | `004` | `onb_next_diary` |
| 4 | Health diary — sample timeline | `005` | `onb_next_assistant` |
| 5 | Assistant — sample conversation | `006` + `007` | `onb_next_pet` |
| 6 | Add first pet — species cards + form | `008` | `onb_pet_name`, `onb_pet_continue` |
| 7 | Activation — personalised, Paw Pal beat | — | `onb_activation_continue` |
| 8 | Welcome — *"You're all set"* | `009` | `onb_finish` |

`000` was **not** implemented and is called out in §6 — it is the sign-in/welcome screen, not a page of the onboarding sequence.

## 2. What was built

`lib/src/onboarding/onboarding_ui.dart` holds the System A presentation layer — navy canvas, emerald primary, cyan co-accent (`UI_ASSET_SPECIFICATION` §1.3) — as primitives: `OnbSurface`, `OnbHeader`, `OnbHeadline`, `OnbSubtitle`, `OnbGlowIcon`, `OnbFeatureCard`, `OnbTrustRow`, `OnbPanel`, `OnbCta`, `OnbStepLabel`, `OnbFooterNote`, `OnbHero`, `OnbPage`. Pages compose from these rather than restyling by hand.

The system is declared once, in `OnbSurface`. Since the shared accent palette resolves to lime for the in-app product, an undeclared subtree would render the wrong system — `system_isolation_test.dart` asserts the boundary.

The star field and paw watermarks are **painted, not shipped as art**: a handful of primitives that scale to any screen and cost nothing in bundle size.

Nothing was duplicated. The species picker became photo cards per mockup `008` by adding a `variant` to the existing `SpeciesChip`, so the pet-edit form keeps its compact chips from the same source.

Logic is untouched: page controller, per-step analytics (names grew with the flow), pet creation, skip, finish, and every widget key.

## 3. Safety — three mockups depict output that breaks the contract

These were **corrected, not reproduced**. Each now follows `007`, which `UI_SAFETY_CONTRACT_REVIEW` names as the compliant reference.

| Mockup | Depicted | Shipped |
|---|---|---|
| `003` | *"Monitor at Home / Low urgency"* and *"**No critical signs detected.** Keep observing…"* — an all-clear terminating in reassurance, with no action and no timeframe (V-14) | **What we observed** → *"An occasional dry cough, no change in appetite or energy."* · **What to do** → *"Keep them rested and watch breathing and appetite."* · **Timing** → *"If it continues past 24–48 hours, or worsens at any point, contact your vet."* + disclaimer |
| `005` | Timeline row *"AI Health Check `Low` — **Mild coughing detected.** Monitor at home."* — a finding plus a severity grade (V-14) | *"AI check — cough noted, keep watching"* |
| `006` | *"Sneezing **can be caused by** mild irritants, **allergies, or infections**."* — names conditions as causes (V-13) | The `007` reply: *"A mild loss of appetite can happen for many reasons"* → things to check → 24–48h → consult your veterinarian |

`004`'s *"PawDoc does not diagnose. We provide AI-powered guidance, not a replacement for your veterinarian."* is kept **verbatim** — the review calls that framing correct.

`test/onboarding_system_a_test.dart` pins all three as absent and asserts the samples still carry a timeframe and a disclaimer. A later pass "restoring fidelity to the design" is precisely how they would return.

## 4. Device validation — Redmi `AYXSUKIVJVPZ7HPZ`, release APK

Walked as a genuinely new user: fresh account created on device, empty state → onboarding → all eight pages → pet created → home.

It caught three defects no test could.

**1 · Heroes rendered as hard-edged rectangles.** The generated plates are opaque — the subject sits on a rendered background, not on alpha — so a photo dropped on the navy canvas drew a visible box. `OnbHero` dissolves the edge with a radial mask.

The first attempt still left a seam on page 8: an outer `SizedBox` spanned the full row width, so on a *portrait* asset the fade zone fell outside the image entirely. `ShaderMask` now sizes to its child.

**2 · The species picker showed a hamster for both Guinea pig and Reptile** — the Phase H fallback doing what it was written to do, and looking plainly wrong for a reptile. Two portraits generated to match the existing cast (**the only image generation in this pass**, well inside the "regenerate a few" bound) and wired in.

**3 · A latent Phase 0 bug**, found while investigating the heroes: the asset pipeline saved WEBP via `convert("RGB")`, silently flattening alpha on every cut-out. Three assets had lost it — `pet-buddy-hero-cutout`, `prm-hero-dog-cat-duo`, `onb-hero-puppy-kitten-splash`. Pipeline fixed; all three re-encoded.

### Verified on device

| | |
|---|---|
| Palette | Navy canvas, emerald headline accent, cyan co-accent — no lime leakage |
| Progress | 8 segments; completed cyan, current emerald with glow |
| Skip | Present on every page, ≥48 dp |
| Heroes | Fade into the canvas, both landscape and portrait |
| Sample panels | Device-framed, live text, correct copy |
| Species cards | All 7 render correct portraits; selection shows emerald border, glow, check badge |
| Pet creation | Saved; page 7 personalised to the name; Paw Pal mount beat plays |
| Finish | `Start my journey` → home |
| Safe areas | Respected top and bottom |
| Scrolling | Every page scrolls; CTA always reachable |

## 5. Before / after

| | Before | After |
|---|---|---|
| Pages | 3 | 8 |
| System | Teal-green, shared with the app | System A — navy + emerald + cyan, isolated |
| Progress | Text-only step count | 8 segments, cyan/emerald, plus `Step N of 8` |
| Headlines | Single-colour `headlineSmall` | Two-line split-colour display |
| CTA | Mint→teal pill | Emerald gradient with glow and chevron |
| Hero art | Cartoon duo illustration | Photoreal cast, edge-dissolved |
| Species picker | Compact chips, emoji fallback | Photo cards; all 7 species have real portraits |
| Product samples | None | Device-framed panels on pages 2, 4, 5 |
| Safety | Compliant | Compliant, and now pinned by test against the mockups' copy |

## 6. Remaining differences

1. **`000` (welcome / sign-in) not implemented.** It is the auth screen — Google / email sign-in — not a page of the onboarding sequence, and its filename breaks the `00N-onboarding` pattern the other eight share. Redesigning it means touching a Google Sign-In path that was fixed only days ago (PR #93). Flagged rather than done; it is a small, self-contained follow-up.
2. **Page 7 has no mockup.** It carries the pet-created moment and the free-checks promise, and is kept from the previous flow with System A styling.
3. **The Paw Pal avatar on page 7 is teal**, not System A. It is the product's mascot rig, not styling — recolouring it is a separate decision.
4. **Photo cards have a slight inner inset** where the mockup's photo fills the card edge-to-edge. Cosmetic, a few pixels.
5. **Page 8's hero keeps a faint bottom edge.** The mockup's animals sit on a green base that the asset does not have; the radial mask softens rather than removes it.
6. **`006` and `007` are merged.** They are near-duplicate assistant pages; merging keeps the flow at 8 steps and uses `007`'s compliant copy for both.
7. **Test accounts created on device:** `onbqa.aug03@example.com`, `onbqa2.aug03@example.com`. Both hold a test pet. Worth deleting from the Supabase project.

## 7. Verification

| Gate | Result |
|---|---|
| `flutter analyze` | Clean |
| `flutter test` | **438 passing, 0 failing** |
| `verify-disclaimers.sh` | PASS |
| `verify-no-placeholders.sh` | OK |
| Release APK | Builds, installs, runs |

New: `onboarding_system_a_test.dart` (6) — System A isolation, the three corrected depictions, 8-step flow with the species picker, Skip target size, and no overflow at 320 dp with 200% text scale.

## 8. Fidelity

**~92% against the mockups**, judged page by page on device.

Layout, spacing, type hierarchy, colour, glow treatment, progress, CTA and card structure match closely. The gap is the six items in §6 — most of it the two unbuilt things (`000`, page 7's absent mockup) rather than drift on what was built.

It is not 99%, and the last points are not reachable by pixel-pushing: three pages carry deliberately different copy because the mockups' text breaks the safety contract. That is a requirement, not a shortfall.
