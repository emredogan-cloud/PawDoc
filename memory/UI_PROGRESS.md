# UI Implementation Program — continuity record

Resume file for the UI migration. Read this first; the roadmap
(`UI_IMPLEMENTATION_ROADMAP.md`) carries the per-phase detail.

**Last updated:** 2026-08-03 · after Phase G

---

## Status

**8 of 18 complete (44%).** ✅ Phase 0 · A · B · C · D · E · F · G — ▶ H — ⏳ I–Q

| PR | Contents | CI |
|---|---|---|
| [#94](https://github.com/emredogan-cloud/PawDoc/pull/94) | Phase 0 — 291 assets + roadmap | green |
| [#95](https://github.com/emredogan-cloud/PawDoc/pull/95) | Phases A–F | green |
| *(open)* | Phase G onward — branch `ui-impl-phase-g-health` | — |

---

## The finding that governs every remaining phase

> **The shipping app is already contract-compliant. The redesign is what would break it.**

`confidence` is parsed off the wire but never rendered; there is no differential
UI; conditions are never named; the disclaimer is gated on the server flag.
Every CRITICAL finding in `UI_SAFETY_CONTRACT_REVIEW` assigned to Phases D and E
— V-01…V-06, V-09 — is a **mockup** violation, not a shipping bug.

So the job is prevention, not remediation. `test/safety_copy_test.dart` is the
tripwire and is **load-bearing**: every remaining phase implements screens whose
mockups violate the contract, and it is the only thing standing between a
faithful implementation and a false negative. Do not weaken it to make a phase
pass — scope it precisely instead (it already excludes `lib/src/models/` from
the confidence scan, because `AnalysisResult` must keep parsing the wire value).

---

## Completed phases

| Phase | Commit | What landed |
|---|---|---|
| 0 | `d17f02a` | 291 production assets sliced from 110 placeholder-named contact-sheet plates; pipeline vendored at `mobile/tool/asset_pipeline/` |
| A | `2eac156` | Both colour ramps + `PawSystem`; contrast measured |
| B | `e88a3b9` | 13-primitive library in `paw_components.dart`; `PawIcon` = Lucide + medical art |
| C | `6e45e39` | New shell; **Emergency a permanent destination** (C-7/V-24) |
| D | `00924e7`, `9d846d9` | Pill grid; `PawCard` migrated all its consumers at once |
| E | `6b5f7da` | `safety_copy_test`; `PawBackground` follows `PawSystemScope` |
| F | `4d272e2` | D-1 pinned on emergency surfaces |
| G | *(branch)* | **App-wide System B `ColorScheme`**; V-22 provenance markers in the exported report |

---

## Decisions in force

- **D-1** Emergency surfaces carry help contacts, first aid, disclaimer, ack gate — nothing else. AI Triage tile, Heat Alert strip **and** the "At Risk Pets / Needs Attention / View Triage" card (found during F, *not* in the review) are all pinned as absent.
- **D-2** Health Score is a lightweight wellness metric only — never diagnosis, clinical score, severity or probability.
- **D-3** Pet cast — **Buddy** golden retriever · **Luna** golden retriever (`pet-luna-retriever-portrait`) · **Milo** tabby cat · **Coco** lop rabbit. One animal per name. `pet-luna-rabbit-avatar` and `pet-milo-shorthair-avatar` become generic species samples. **Specified, not yet applied — do this in Phase H.**
- **D-4** Regenerate only the minimum. Six gaps: `INF-504`, `CMN-1403`, `BRE-1301` cat/rabbit/bird, AVT map/group, `onb-hero-puppy-kitten-splash`, `onb-glyph-cross`. `OPENAI_API_KEY` is in `.env`. **Not yet run.**
- **D-5** Payment marks from official brand kits only; never AI-generated. **Not sourced.**
- **D-6** Lucide for the core + nav icon set; bespoke medical families stay as tinted PNG (Lucide has no `parvovirus` glyph).
- **C-7 / V-24** Emergency keeps a permanent nav slot; Premium reached from Account and contextual upsells.

---

## Architecture notes for whoever resumes

1. **Two agreeing paths to System B.** The Material `ColorScheme` (Phase G) and `PawSystemScope`/`PawTone` both resolve to the same values. Screens migrate by *either* route, so most remaining phases are re-skins, not rewrites.
2. **Change the primitive, not the screen.** `PawCard` and `PawBackground` each migrated every consumer in one commit. Prefer that over per-screen edits.
3. **`PawSystem.legacy` is the escape hatch** for anything not yet migrated; onboarding must declare `PawSystem.a` so its navy/emerald never leaks (Phase P).
4. **Keys are contracts.** Home tests address widgets by key; preserve them verbatim when restyling.
5. **Lucide is font-based**, so `color` behaves exactly like `currentColor` — the emergency red colourway is a colour argument, never a second asset set.

---

## Regressions avoided (do not re-introduce)

- Section-header "See All" was a **42dp** target — fixed by constraining, not padding.
- New black cards were rendering on the **old teal gradient**; only device validation caught it.
- Light-mode lime: `#A3E635` is **1.51:1 on white**; `#65A30D` only 3.09:1. Use `lime700 #4D7C0F`.
- `assets/brand/logo_mark_v1.png` had been moved out of its tracked path, breaking `motion_assets_test`.

---

## Gotchas

- **CI only runs on `pull_request` and pushes to `main`** — a branch push alone does not trigger it.
- `assets/_plates/` (150 MB) is gitignored and must never be declared in `pubspec.yaml`; `ui_assets_test` guards this.
- A release build can **fail silently** behind `cmd | tail -n` — check the APK mtime against source mtime before concluding "the fix didn't work".
- Device is locked on wake; swipe up before screenshotting or you capture the lock screen.
- `new-interface/` (57 mockups, 93 MB) is still untracked — owner's call.

---

## Remaining

⏳ **H** Pets (3) + apply D-3 · **I** Assistant (4; V-11, V-12, V-18, V-23) · **J** Memories (4) · **K** Lifestyle (3; V-20) · **L** Encyclopedia (2) · **M** Community (4) · **N** Premium (4; V-15) · **O** Account (5) · **P** Onboarding (9; System A isolation, V-13–V-15) · **Q** Hardening + final report.
