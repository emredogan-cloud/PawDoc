# PawDoc — UI Implementation Report

**Date:** 2026-08-03
**PRs:** [#94](https://github.com/emredogan-cloud/PawDoc/pull/94) (Phase 0) · [#95](https://github.com/emredogan-cloud/PawDoc/pull/95) (Phases A–F)
**Status:** Phase 0 + Phases **A–F of A–Q** complete, verified, device-validated. **Phases G–Q not started.**

---

## 1. Headline

This report is titled "final" because the brief asked for that filename. It is not a completion report, and saying so is the most useful thing in it: **6 of 17 phases are done.** What is done is finished properly — analyzed, tested, built, installed on the Redmi, and pushed with CI. What is not done is listed in §7 with no softening.

The single most consequential finding of the whole program is not a pixel:

> **The shipping app is already contract-compliant. The redesign is what would break it.**

`confidence` is parsed off the wire but never rendered. There is no differential UI. Conditions are never named. The disclaimer is gated on the server-forced flag. Every CRITICAL finding assigned to Phases D and E — V-01 through V-06 and V-09 — turned out to be a **mockup** violation, not a shipping bug.

That inverts the job. There was nothing to remediate; there is a great deal to *prevent*, over eleven remaining phases, each of which asks an implementer to reproduce a mockup that renders `68% confidence`, `21% / 7% / 4%`, "Potential Concern: Skin Infection", or "No signs of a serious condition". The highest-value artifact produced is therefore a test, not a screen.

---

## 2. Phases completed

### Phase 0 — Asset preparation (`d17f02a`)

The stated premise was that asset generation was complete. It was not. 110 PNGs existed, saved under the specification's **unexpanded filename placeholders** — `ic-symptom-<name>.svg.png`, `mem-buddy-{01..24}@3x.webp.png` — where each file is a contact sheet holding an entire set. Nothing was addressable by the name the implementation expects; nothing was declared in `pubspec.yaml`, so none of it reached the bundle.

**291 individually-named production files** were produced (`mobile/tool/asset_pipeline/`):

- Icon plates have gutters → recursive projection-profile splitting, 19/19 families sliced to exactly their specified counts. Photo mosaics are edge-to-edge → explicit grids; two are unevenly divided and use measured seam fractions.
- **Backdrop removal needs four modes.** A single white key erases the white cloud *inside* a weather icon and the white pictogram *inside* a first-aid tile. `flood` removes only border-connected white; `key` preserves hue for coloured outline glyphs; `white` suits monochrome line art, whose interiors *should* drop so the glyph stays tintable; `dark` un-composites neon off black.
- Resizing is **premultiplied** — cut-outs carry garbage colour beneath `alpha=0` that a naive downscale samples into a halo.
- Four plates had the transparency checkerboard rendered as opaque pixels; the memory grid had `01`–`24` burned into every tile.
- Sizes capped by intended use (art drawn at 96 pt had been emitted at 1024–1536 px): **44 MB → 12 MB**.

### Phase A — Design system (`2eac156`)

Both ramps added as tokens, not swapped, with `PawSystem` declaring which system a subtree belongs to.

Contrast was **measured, and one measurement changed the design**: lime `#A3E635` is 13.93:1 on black but **1.51:1 on white**, and the obvious darkening `#65A30D` still reaches only 3.09:1 — large/UI only, not body text. Light mode uses `lime700 #4D7C0F` (4.99:1 on white, 4.75:1 on the app's off-white).

`design_tokens_test.dart` pins the safety-locked action-ladder hues by literal value and asserts no brand accent equals a status hue — lime reading as "all clear" is precisely the failure the contract forbids.

### Phase B — Component library (`e88a3b9`)

Thirteen primitives in a **new** file. Restyling `paw_ui.dart` in place would have restyled 29 screens in one commit; screens migrate onto the new components phase by phase instead.

`PawIcon` unifies two sources behind one call shape: Lucide for the core set — font-based, so `color` tints it exactly like `currentColor`, which keeps the emergency red colourway a colour argument rather than a duplicate file set — and the bespoke medical art, which has no Lucide equivalent (there is no `parvovirus` glyph).

The tests caught a real defect: the section-header "See All" target was **42 dp**, under the 48 dp minimum. Fixed by constraining the target rather than padding the label.

### Phase C — Navigation (`6e45e39`)

```
[Home]  [Pets]  [＋]  [Health]  [Emergency]
```

Resolves conflict **C-7 / review V-24**. The mockups' Variant B puts Premium in the slot that otherwise holds Emergencies across nine screens, displacing the fastest route to GET_HELP_NOW with a paywall surface.

The result is **stronger than what shipped**: Emergency previously lived only on Home — one tap from one screen. It is now one tap from every tab.

### Phase D — Home (`00924e7`)

Secondary navigation moved onto the mockup's pill grid. Every widget key preserved verbatim, because the home tests address them by key.

### Phase E — Safety tripwire (`6b5f7da`)

`safety_copy_test.dart` — source-level assertions that no confidence reaches the UI, no condition is named in AI output, no all-clear headline exists, no differential vocabulary appears, the Health Score is never labelled clinically (**owner decision D-2**), the emergency package imports neither analysis nor monetisation code, and both result screens still gate on `disclaimerRequired`.

Two scoping decisions, made after the first run flagged legitimate code rather than by loosening the rule:
- `lib/src/models/` is excluded from the confidence scan — `AnalysisResult` must keep parsing the value; the contract is frozen across Dart/Python/TS and the server uses it to gate "insufficient information". The rule is that it never reaches a *user*.
- The condition-name scan is scoped to AI-output surfaces, because generic breed education ("keep wrinkles clean and dry to prevent skin infections") is not AI output about a specific animal — the same line `result_screen.dart` already draws.

### Phase F — Emergency (`4d272e2`)

Reading `emergency_hub.png` surfaced a **third rule-4 violation the review did not catalogue**. Alongside the known AI Triage tile (V-16) and Heat Alert strip (C-6), the mockup carries an **"At Risk Pets 1 / Needs Attention / Based on recent symptoms (Vomiting, Loss of appetite) / View Triage"** card — a model-derived triage verdict placed directly on the red path.

Owner decision **D-1** removes all three. None was ever built, so this phase adds the tripwire rather than a fix.

---

## 3. Device validation

Real device: **Redmi, `AYXSUKIVJVPZ7HPZ`**, release APK, installed and driven via ADB.

It caught a defect the test suite could not: the new black cards and black nav bar were rendering on the **old teal gradient** — two visual systems stacked in one screen. No unit test can see that. Fixed by making `PawBackground` follow `PawSystemScope`, and the legacy botanical decor is suppressed outside `PawSystem.legacy`, where it read as smudges on near-black.

| Check | Result |
|---|---|
| Canvas | Pure black after the fix; legacy particles gone |
| Nav bar | Home · Pets · ＋ · Health · **Emergency in red** |
| Lucide icons | Render correctly (house, paw, heart-pulse, circle-alert, history, images, clipboard, book-open) |
| Pill grid | Correct, no truncation |
| **Emergency destination** | Opens the red screen: emergency-vet + poison-control contacts, first-aid list. **No AI affordance, no upsell, no meter.** |
| Emergency offline capability | Source scan: **zero network calls** in `lib/src/emergency/` |
| APK | 138.9 MB fat (3 ABIs); `_plates` confirmed absent — 0 entries |

One process note worth recording: an intermediate release build **failed silently** because the command was `cd mobile && … ; flutter build … | tail -3` — the `cd` failed (cwd was already `mobile`), the `&&` short-circuited the env load, and the pipe masked the exit code, so a stale APK was installed and mis-read as "the fix didn't work". Checking the APK mtime against the source mtime is what surfaced it.

---

## 4. Verification

| Gate | Result |
|---|---|
| `flutter analyze` | Clean |
| `flutter test` | **422 passing, 0 failing** (373 at Phase 0 → 422) |
| `verify-disclaimers.sh` | PASS |
| `verify-no-placeholders.sh` | OK |
| Release APK | Builds, installs, runs |
| CI (PR #94) | All 7 jobs green |

New tests: `ui_assets_test` (5) · `design_tokens_test` (11) · `paw_components_test` (19) · `root_shell_test` (9) · `safety_copy_test` (10).

---

## 5. Visual accuracy

**Honest estimate: ~35% of the redesign is on screen**, and that number is not comparable to the brief's 99% target, because the target measures per-screen fidelity of *implemented* screens while this measures how much of the app has been migrated at all.

Of what has been migrated:

| Element | Fidelity |
|---|---|
| Canvas / colour system | High — pure black, correct lime |
| Bottom navigation | High, with a deliberate structural change (Emergency added, Settings to header) |
| Pill grid, icons | High |
| Home feature cards (pet hero, breed insight, walks, community) | **Not migrated** — still legacy teal |
| All other screens | **Not migrated** |

---

## 6. Deliberate deviations

Recorded rather than silently applied, per this project's working agreement.

1. **Emergency keeps its full-red canvas** where `emergency_hub` draws black with red accents. Colour is the fastest signal on that surface, the red treatment is already device-validated, and softening it would trade an unmistakable safety cue for visual consistency. The mockup's hub layout (clinic map, rated cards, checklist) is a feature build, not a re-skin, and is deferred.
2. **Navigation is 4 destinations + centre action**, not the mockup's 6 slots. Emergency had to be added without pushing targets below 48 dp at 320 dp; Assistant moved to the centre sheet (it is an action) and Settings to the Home header avatar, which the mockup already draws.
3. **No `/dev/gallery` route** — not worth adding router surface for a one-off visual check.
4. **19 screens will never be pixel-matched.** Their content breaks the contract. Corrected copy is layout-preserving, so geometry holds; the words differ. This is not a shortfall.

---

## 7. Not done

Phases **G–Q**, in roadmap order:

| Phase | Screens | Safety findings still open |
|---|---|---|
| G Health records | 8 | V-08, V-10, V-19–V-22 |
| H Pets | 3 | — |
| I Assistant | 4 | V-11, V-12, V-18, V-23 |
| J Memories | 4 | — |
| K Lifestyle | 3 | V-20 |
| L Encyclopedia | 2 | — |
| M Community | 4 | — |
| N Premium | 4 | V-15 |
| O Account | 5 | §4.2 |
| P Onboarding | 9 | V-13–V-15 |
| Q Hardening | all | S2/S3/S4 |

Also outstanding:

- **Asset regeneration (owner decision D-4).** Six gaps remain: `INF-504` size-reference (checkerboard baked through the silhouettes), `CMN-1403` reaction chips (one overlapping cluster), `BRE-1301` cat/rabbit/bird tiles (all rendered as golden retrievers), AVT map/group avatars (wrong subjects), `onb-hero-puppy-kitten-splash` (a blue paw icon), `onb-glyph-cross`. `OPENAI_API_KEY` is present; ~10 images — below the "stop and produce a prompt sheet" threshold, but not yet run.
- **Payment marks (D-5).** `TPB-1701`–`1703` must come from official brand kits. Not sourced. Never AI-generate them.
- **Pet cast (D-3).** Not yet applied. Proposed, consistent, and supported by the shipped assets: **Buddy** = golden retriever, **Luna** = golden retriever (`pet-luna-retriever-portrait`), **Milo** = tabby cat, **Coco** = lop rabbit — one animal per name, species-diverse. `pet-luna-rabbit-avatar` and `pet-milo-shorthair-avatar` become generic species samples.
- **`new-interface/`** (57 mockups, 93 MB) is still untracked — a repo-weight call.

---

## 8. Recommendation

Continue in roadmap order, one phase per session, keeping the device pass after each. Phase G is the natural next step: it is the largest remaining screen group and carries six safety findings, all copy-only and layout-preserving.

Before Phase P, run the D-4 regeneration — two of the six gaps (`onb-hero-puppy-kitten-splash`, `onb-glyph-cross`) are onboarding assets, and it is cheaper to have them in hand than to build around fallbacks and revisit.

The `safety_copy_test.dart` tripwire should be treated as load-bearing. Every remaining phase implements screens whose mockups violate the contract, and it is the only thing standing between a faithful implementation and a false negative.
