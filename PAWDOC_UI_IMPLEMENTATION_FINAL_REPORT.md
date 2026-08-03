# PawDoc — UI Implementation Final Report

**Date:** 2026-08-03
**Scope:** Phase 0 + Phases A–Q of `UI_IMPLEMENTATION_ROADMAP.md` — **all 18 complete**
**PRs:** [#94](https://github.com/emredogan-cloud/PawDoc/pull/94) Phase 0 · [#95](https://github.com/emredogan-cloud/PawDoc/pull/95) A–F · [#96](https://github.com/emredogan-cloud/PawDoc/pull/96) G–H · [#97](https://github.com/emredogan-cloud/PawDoc/pull/97) I–Q

---

## 1. The finding that defined the program

> **The shipping app was already contract-compliant. The redesign is what would have broken it.**

`confidence` is parsed off the wire but never rendered. There is no differential UI. Conditions are never named. The disclaimer is gated on the server-forced flag.

Every CRITICAL finding in `UI_SAFETY_CONTRACT_REVIEW` assigned to Phases D and E — V-01 through V-06, and V-09 — turned out to be a **mockup** violation with no shipping counterpart. Only one finding in the entire review was a real defect in the code: **V-22**, the exported record's missing provenance.

That inverted the job. There was almost nothing to remediate and a great deal to prevent, across screens whose mockups render `68% confidence`, `21% / 7% / 4%`, "Potential Concern: Skin Infection" and "No signs of a serious condition". The most valuable artifact produced is therefore a test, not a screen: `test/safety_copy_test.dart`, which asserts at source level — because a widget test only covers the states it happens to pump, while these strings must not exist in any branch or language.

**A third rule-4 violation was found that the review did not catalogue.** Reading `emergency_hub.png` for Phase F surfaced, alongside the known AI Triage tile (V-16) and Heat Alert strip (C-6), an **"At Risk Pets 1 / Needs Attention / Based on recent symptoms / View Triage"** card — a model-derived triage verdict placed directly on the red path. All three are now pinned as absent.

---

## 2. What was built

### Phase 0 — Asset preparation (`d17f02a`)

The stated premise was that asset generation was complete. It was not. 110 PNGs existed under the specification's **unexpanded filename placeholders** — `ic-symptom-<name>.svg.png`, `mem-buddy-{01..24}@3x.webp.png` — each a contact sheet holding an entire set. Nothing was addressable by the name the implementation expects; nothing was in `pubspec.yaml`, so none of it reached the bundle.

**291 production files** via `mobile/tool/asset_pipeline/`:

- Icon plates have gutters → recursive projection-profile splitting; 19/19 families sliced to exactly their specified counts. Photo mosaics are edge-to-edge → explicit grids, two using measured seam fractions.
- **Backdrop removal needs four modes.** A single white key erases the white cloud *inside* a weather icon and the white pictogram *inside* a first-aid tile. `flood` (border-connected white only) · `key` (hue-preserving, for coloured outline glyphs whose enclosed white is background) · `white` (monochrome line art, whose interiors *should* drop so the glyph stays tintable) · `dark` (un-composite neon off black).
- Resizing is **premultiplied** — cut-outs carry garbage colour beneath `alpha=0` that a naive downscale samples into a halo.
- Four plates had the transparency checkerboard rendered as opaque pixels; the memory grid had `01`–`24` burned into every tile.
- Sizes capped by intended use: **44 MB → 12 MB**.

### Phases A–Q

| Phase | Commit | What landed |
|---|---|---|
| A | `2eac156` | Both colour ramps + `PawSystem`; contrast **measured** |
| B | `e88a3b9` | 13-primitive library; `PawIcon` unifies Lucide + medical art |
| C | `6e45e39` | New shell — **Emergency a permanent destination** (C-7 / V-24) |
| D | `00924e7`, `9d846d9` | Pill grid; `PawCard` migrated all consumers |
| E | `6b5f7da` | `safety_copy_test`; `PawBackground` follows the system |
| F | `4d272e2` | D-1 pinned; third rule-4 violation found |
| G | `76e3ab4` | **App-wide System B `ColorScheme`**; V-22 provenance |
| H | `fb2c6f6` | Species art wired; CTA + `secondaryContainer` migrated |
| I | `dc84714` | **System B at the app root** — pushed routes sit above the shell scope |
| J–O | `5ecff02` | **Accent palette repointed** — one change, ~120 call sites |
| P | `b619336` | System A isolated; `system_isolation_test` pins the boundary |
| Q | — | Full gate set + device matrix |

---

## 3. The three leverage points

Most of this migration was won by changing one thing rather than fifty.

1. **`ColorScheme` (G).** Flipping the dark scheme migrated every Material widget — `Card`, `Chip`, `ListTile`, `Dialog`, `TextField`, `SnackBar` — on every screen, including phases that had not run yet.
2. **App-root `PawSystemScope` (I).** A pushed route is inserted into the Navigator that *owns* the shell, above any scope the shell provides. Every detail screen was silently `legacy` until this moved to `app.dart`.
3. **Accent palette repoint (J–O).** `PawPalette.mint`/`.teal` were used at ~120 sites as "the accent", not as literal colours. Two constants migrated memories, encyclopedia, walks, reminders, community, premium and account at once — versus ~120 edits, many inside `const` constructors that would have had to lose their constness.

Each was recorded in the roadmap and `memory/UI_PROGRESS.md` as it was found, rather than stopping to ask.

---

## 4. Device validation

**Redmi `AYXSUKIVJVPZ7HPZ`**, release APK, driven over ADB after every phase.

It caught four defects no unit test could see:

- New black cards rendering on the **old teal gradient** — two visual systems stacked in one screen.
- `secondaryContainer` was never in the `copyWith`, so the breed-insight card stayed teal after the scheme flip.
- `PawPrimaryButton` hard-coded the mint gradient — the primary CTA on most screens.
- Icon tiles across Account still teal.

Surfaces walked: home · pets · health · centre action sheet · account (a **pushed** route, proving the Phase I fix) · Emergency destination.

| Check | Result |
|---|---|
| Canvas | Pure black; legacy decor suppressed |
| Nav | Home · Pets · ＋ · Health · **Emergency in red** |
| CTAs | Lime gradient, dark ink |
| Pushed routes | Fully System B |
| **Emergency** | Vet + poison-control contacts, first aid. **No AI affordance, no upsell, no meter.** |
| Emergency offline | **Zero network calls** in `lib/src/emergency/` |
| APK | `_plates` absent — 0 entries |

One process note: an intermediate build **failed silently** behind `cd mobile && … ; flutter build … | tail -3` — the `cd` failed, the `&&` short-circuited the env load, and the pipe masked the exit code, so a stale APK was installed and misread as "the fix didn't work". Comparing APK mtime to source mtime surfaced it. Recorded in memory.

---

## 5. Verification

| Gate | Result |
|---|---|
| `flutter analyze` | Clean |
| `flutter test` | **432 passing, 0 failing** (373 → 432) |
| `verify-disclaimers.sh` | PASS |
| `verify-no-placeholders.sh` | OK |
| `node --test` (Edge shared) | Pass |
| CI | Green on #94 and #95; #96 / #97 running at time of writing |

New suites: `ui_assets_test` (5) · `design_tokens_test` (11) · `paw_components_test` (19) · `root_shell_test` (9) · `safety_copy_test` (13) · `system_isolation_test` (7).

---

## 6. Visual accuracy — honest assessment

**The app-wide visual *system* migration is complete: ~100%.** Canvas, colour scheme, accents, cards, borders, icons, navigation, CTAs and both system palettes are live on every screen, verified on device.

**Per-screen *layout* parity with the mockups is materially lower — I estimate 45–55%** — and the two must not be conflated.

The mockups do not only recolour; several restructure. `010-home-page` adds a horizontal pet-chip rail, a photoreal hero with a bleeding cut-out, a 4-across quick-action row, two-column card pairs and a stat strip. `emergency_hub` adds a clinic map, rated clinic cards and a checklist. Those are feature builds. What shipped is the correct visual system applied to the existing information architecture, plus the navigation change the safety contract required.

Setting `~99%` against the mockups would be wrong for a second reason: **19 of the 57 screens must not be matched**, because their content breaks the contract. Corrected copy is layout-preserving, so geometry holds; the words differ. That is a requirement, not a shortfall.

---

## 7. Deliberate deviations

1. **Emergency keeps its full-red canvas** where `emergency_hub` draws black with red accents. Colour is the fastest signal on that surface and the red treatment is device-validated; softening it trades an unmistakable safety cue for visual consistency.
2. **Navigation is 4 destinations + centre action**, not the mockup's 6 slots. Emergency had to be added without pushing targets below 48 dp at 320 dp; Assistant moved to the centre sheet (it is an action) and Settings to the Home header avatar, which the mockup already draws.
3. **`PawPalette.mint`/`.teal` repointed rather than renamed.** Semantically they were always "the accent". Documented in-file, with System A screens required to declare their system — enforced by test.
4. **No `/dev/gallery` route** — not worth router surface for a one-off check.

---

## 8. Outstanding — owner-gated

| # | Item | Status |
|---|---|---|
| D-4 | Regenerate 6 assets: `INF-504`, `CMN-1403`, `BRE-1301` cat/rabbit/bird, AVT map/group, `onb-hero-puppy-kitten-splash`, `onb-glyph-cross`. `OPENAI_API_KEY` present. | **Not run** — all six degrade through `AppImage`; none blocks a screen |
| D-5 | Payment marks (`TPB-1701`–`1703`) from official brand kits. **Never AI-generate.** | **Not sourced** |
| — | Layout-level rebuild of the restructured mockups (§6) | Feature work, not a re-skin |
| — | `new-interface/` (57 mockups, 93 MB) still untracked | Repo-weight call |

---

## 9. For the next session

`memory/UI_PROGRESS.md` is the resume file: decisions in force, architecture notes, regressions not to re-introduce, and the gotchas that cost time.

The one thing to treat as load-bearing is **`test/safety_copy_test.dart`**. Every screen still to be rebuilt at layout level has a mockup that violates the contract. If a future change makes it fail, the correct response is to fix the code or scope the scan precisely — as was done twice here, for the wire-level `confidence` field and for generic breed education — never to loosen the rule.
