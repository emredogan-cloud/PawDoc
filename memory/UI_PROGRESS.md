# UI Implementation Program — continuity record

Resume file for the UI migration. Read this first; the roadmap
(`UI_IMPLEMENTATION_ROADMAP.md`) carries the per-phase detail.

**Last updated:** 2026-08-04 · onboarding complete + home and the AI Health Check flow rebuilt

---

## Status

**18 of 18 complete (100%).** ✅ Phase 0 · A–Q

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
| G | `76e3ab4` | **App-wide System B `ColorScheme`**; V-22 provenance markers in the exported report |
| H | `fb2c6f6` | Species art wired; `AppAssets.species()` had pointed at an empty folder since M2. Primary CTA + `secondaryContainer` migrated |
| I | `dc84714` | **System B declared at the app root** (pushed routes sit above the shell scope). Assistant audited clean; V-12/V-23 pinned |
| J–O | `5ecff02` | **Accent palette repointed** — one change migrated ~120 call sites across memories, encyclopedia, walks, reminders, community, premium, account |

---

## Decisions in force

- **D-1** Emergency surfaces carry help contacts, first aid, disclaimer, ack gate — nothing else. AI Triage tile, Heat Alert strip **and** the "At Risk Pets / Needs Attention / View Triage" card (found during F, *not* in the review) are all pinned as absent.
- **D-2** Health Score is a lightweight wellness metric only — never diagnosis, clinical score, severity or probability.
- **D-3** Pet cast — **Buddy** golden retriever · **Luna** golden retriever (`pet-luna-retriever-portrait`) · **Milo** tabby cat · **Coco** lop rabbit. One animal per name. `pet-luna-rabbit-avatar` and `pet-milo-shorthair-avatar` become generic species samples. Species→art mapping applied in H. Name→animal binding is sample-data only and lands with the screens that show the cast.
- **D-4** Regenerate only the minimum. Six gaps: `INF-504`, `CMN-1403`, `BRE-1301` cat/rabbit/bird, AVT map/group, `onb-hero-puppy-kitten-splash`, `onb-glyph-cross`. `OPENAI_API_KEY` is in `.env`. **Not yet run.**
- **D-5** Payment marks from official brand kits only; never AI-generated. **Not sourced.**
- **D-6** Lucide for the core + nav icon set; bespoke medical families stay as tinted PNG (Lucide has no `parvovirus` glyph).
- **C-7 / V-24** Emergency keeps a permanent nav slot; Premium reached from Account and contextual upsells.

---

## Architecture notes for whoever resumes

1. **Two agreeing paths to System B.** The Material `ColorScheme` (Phase G) and `PawSystemScope`/`PawTone` both resolve to the same values. Screens migrate by *either* route, so most remaining phases are re-skins, not rewrites.
2. **Change the primitive, not the screen.** `PawCard` and `PawBackground` each migrated every consumer in one commit. Prefer that over per-screen edits.
3. **Declare the system at the app root, not the shell.** A pushed route is inserted into the Navigator that *owns* RootShell, above any scope the shell provides — detail screens silently stayed `legacy` until `app.dart` declared it. Onboarding must override to `PawSystem.a` so its navy/emerald never leaks (Phase P).
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

## Onboarding rebuild — COMPLETE

Scope was narrowed by the owner to **onboarding only**. All eight mockups
(`002`–`009`) are implemented, device-walked on the Redmi (393x851 logical,
the same size the mockups are drawn at) and committed.

**Flow, as shipped:**

    app open (0001) -> onboarding 002..009 -> auth gateway (000)
                    -> Google | Email | Guest -> Home

**One page per mockup.** The flow used to collapse `006`+`007` into one page
and invent an activation page to fill the gap, so neither assistant mockup was
on screen. It is now 1:1, which is also the `Step N of 8` the later mockups
print in their own footers. Page keys: `onb_get_started`, `onb_next_emergency`,
`onb_next_diary`, `onb_next_assistant`, `onb_next_chat`, `onb_next_pet`,
`onb_pet_continue`, `onb_finish`.

| Page | Commit | What landed |
|---|---|---|
| 002 | `e26b441` | whole uncropped hero, `_PlateEdgeFade`, cyan ribbon in FRONT, side notes, trust card |
| 003 | `dc67e5e` | real iPhone plate, live AI screen, scan-ring bloom, 4 orbiting glyphs |
| 004 | `699f503` | two neon glass cards + the `≠` light collision, transparency panel, 24/7 trust strip |
| 005 | `699f503` | 5-stop rail + dotted spine, device with a live diary, callout bubble, the pair bleeding off the right |
| 006 | `e61aab5` | robot crest, chat device, 2+2 tethered cards, privacy strip, blanket hero under the CTA |
| 007 | `e61aab5` | paw+plus crest, chat device, 3+3 tethered cards, safety strip, halo hero |
| 008 | `76b9988` | species photo gallery, 2-column record card, photo well + dashed upload, benefits, privacy |
| 009 | `76b9988` | success crest, celebration hero in a paw field, spark rule, 4 tiles, PRIVATE BY DESIGN |

### Two blockers found by walking the flow (not by any test)

1. **The add-pet step could not be passed at all.** The journey now runs
   *before* authentication and `PetsRepository.create` reads
   `auth.currentUser!.id`, so the write threw a null check the page swallowed
   as "Could not save your pet. Try again." Fixed with `PendingPet` — the draft
   (and the photo bytes + crop, since uploading also needs a JWT) is held in
   memory and created on the first authenticated frame in `RootShell`, the one
   surface every sign-in path lands on.
2. **Finishing looped back to the beginning.** `_finish` went to `/`, and the
   router redirects an unauthenticated `/` to `/welcome` until `FirstRun` is
   marked done — which only the gateway does. Onboarding now exits to
   `/auth-gateway` signed out, home signed in.

### Things worth knowing before touching this again

- **The mockups are AI-rendered pictures, not exported frames.** At 853px for a
  393dp screen the type measures ~27dp display, ~12dp deck, ~9.5dp body and
  ~8dp inside the rails — the last two are unreadable on a handset. Layout,
  spacing and composition are matched exactly; type sits ~15% above the naive
  scale and the device gives back the width that costs. Page gutter is 18dp,
  measured, not 20.
- **`onb-hero-dog-kitten-cutout` was never a cutout** — a rendered checkerboard
  baked into RGB. The auth gateway had been drawing that checkerboard. Keyed by
  flood-filling the light neutral **from the border only** (interiors survive),
  eroded 2px to swallow the matte fringe, then feathered.
- **`BlendMode.screen` is the tool for every supplied hero.** They are rendered
  on black, black is `screen`'s identity, and the canvas is nearly black — so
  the plate merges with no matte line and the animals come through unchanged.
- **A notched card in an `IntrinsicHeight` row needs `StackFit.passthrough`**,
  or each card keeps its own intrinsic height and the borders end at different
  places.
- **Size a flanking-card stage from the card row, not a fixed box.** `007`
  stacks three cards a side, taller than the device; a hard height clipped them
  by 35px and only device validation showed it.
- **`SpeciesChip` resolves its accent through the app palette**, which points at
  lime — so on a System A page the selected chip renders lime-on-navy. The
  isolation test does not reach it. `SpeciesGallery` takes its colour from the
  page instead.

### Deliberate departures from the reference

| Where | Reference | Shipped | Why |
|---|---|---|---|
| `004` right card | "Not Urgent" | "Keep Watching" | a triage verdict, and the closest thing in the flow to an all-clear; the ladder has no "do nothing" rung |
| `004` deck | "Instant emergency detection" | "Step-by-step emergency guidance" | promises a reliability the pipeline does not claim |
| `005` diary row | "Mild coughing detected" + `Low` badge + "Monitor at home" | an observation + a recheck window, no badge | finding + severity grade + terminating instruction (V-14) |
| `006` answer | "Sneezing can be caused by mild irritants, allergies, or infections" | checks observations, closes on a timeframe | names conditions as causes (V-13) |
| `005` rail hue | amber | rose | amber is `monitorLight`, a safety-locked status colour |
| `009` sign-off | handwriting face | italic accent | the bundle ships Bricolage + Inter; a fifth webfont for one line is not worth it |
| `004`/`005` footer | dots | dots | kept; `006`–`009` keep `Step N of 8`, as each mockup draws it |

### Known limitations

- The `008` photo preview shows the picked image under `BoxFit.cover`, which is
  exactly the crop for an untouched (centred) frame but not for a moved one.
  The upload always uses the real crop.
- The auth gateway (`000`) has not been re-walked against its own mockup — its
  hero shield overlaps the dog and the social-proof line ellipsizes. Out of the
  004-009 scope; next candidate.
- `002`'s hero still shows faint plate edges at the sides.

## Post-onboarding screens — mockups 010 and the AI Health Check flow

**Last updated:** 2026-08-04. Five screens, all device-walked on the Redmi.

| Mockup | Where it lives | Commit |
|---|---|---|
| `010-home-page` | `home/home_screen.dart` + `home/home_sections.dart` | `3881f38` |
| `ai_health_check_start` | `health_check/health_check_start_screen.dart` | `6eb63e5` |
| `photo_analysis_upload` | `health_check/health_check_photo_screen.dart` | `6eb63e5` |
| `symptom_selection` | `health_check/health_check_symptoms_screen.dart` | `6eb63e5` |
| `ai_analysis_loading` | `health_check/health_check_loading_view.dart` | `6eb63e5` |

Shared: `health_check/health_check_chrome.dart` (header, node rail, disclaimer
strip, pinned-action scaffold) and `home/home_sections.dart` (`HomeCard`,
`HomeCardHeader`, `HomeBrandBar`, `PetRail`, `PetPortrait`, `HomeGreeting`,
`PetHeroPanel`, `HomeListCard`, `HomeQuickActions`, `HomeStatStrip`).

### Onboarding: the CTA is pinned (`295fff5`)

Every page opened with its Next button below the fold. `OnbPage` now pins the
footer over a fade strip and scrolls the content beneath it — the CTA lands
where the mockups draw it and is reachable on the first frame of all eight
pages. The footer **measures itself**; a constant left `002`'s trust card
hidden, because that page carries a footnote under its CTA. `OnbSpacing` /
`OnbGap` scale the page-level gaps with the viewport (0.68–1.08 against the
780dp the mockups are composed for); artwork and type never scale.

### Safety departures from these five mockups

| Where | Reference | Shipped |
|---|---|---|
| `010` hero | "Buddy is doing great!" / "No health issues detected" | the last-check line — both mockup phrasings are all-clears `safety_copy_test` bans by regex |
| `010` stat ring | "Health Score · 92 · Excellent" | "Care Score", computed from record completeness and captioned as such (D-2) |
| `010` hero signals | Energy High · Mood Happy · Activity Good | drawn as-is, marked "Soon" — nothing records them, and inventing them is a claim about an animal nobody observed |
| start screen | "Identify irritation, allergies & more", "Check for signs of infection" | what the owner can *describe* — the mockup names conditions |
| start screen | Recent check: "Low risk" | the action the check ended on; severity is never graded |
| symptoms | "understand your pet's condition better" | "understand what you are seeing" |

### Things that bit, worth remembering

- **`IntrinsicHeight` cannot measure a `LayoutBuilder`.** Making `WalkCard`
  responsive silently blanked the entire two-column block until the
  `IntrinsicHeight` around it came off.
- **Full-width cards collapse in a 170dp column.** `WalkCard` and
  `CommunityCard` put a 32dp glyph, the copy and a trailing control in one row;
  the copy got ~40dp and rendered one character per line. Both now stack below
  260dp.
- **`PawPillButton` ellipsised half the home grid.** It shrinks to fit now — a
  truncated destination is worse than a smaller one.
- **`Wrap` sizes each child independently**, so the symptom grid came out
  ragged until the tiles took a fixed height.
- **The nav bar is untouched.** The `010` mockup's Assistant/Settings
  destinations would displace Emergency, which C-7 pins as permanent.
- **Anonymous sign-in is failing on the dev Supabase project** ("Could not
  start a guest session"), so device validation went through an email account.
  Founder-side config, not a code defect.

## Remaining

All phases complete. Screen-by-screen rebuild against `new-interface/` is at
**53 of 58** — the five left are the settings surfaces (`account_management`,
`profile`, `privacy_security`, `notifications`, `ai_transparency`), plus the
two pre-auth screens which exist but were never re-walked (`000`, sign-in).
Owner-gated: D-4 asset regeneration (6 gaps), D-5 payment marks.
See `RESUME_GUIDE.md` for the live state.
