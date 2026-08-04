# UI Implementation Changelog

Chronological record of the UI migration (Phase 0 + A–Q). Detail lives in
`UI_IMPLEMENTATION_ROADMAP.md`; rationale in
`PAWDOC_UI_IMPLEMENTATION_FINAL_REPORT.md`; resume state in
`memory/UI_PROGRESS.md`.

## 2026-08-04 (later) — the analysis wait, and the result screen

- **Result** `4ff08ef` — rebuilt against `ai_analysis_result_low_risk` and
  `_monitor`. The two most contract-hostile mockups in the set: confidence
  percentages, a risk level, a named cause, a ranked differential and an
  all-clear checklist, all in one screen. Every card, glyph and position is
  reproduced; every claim is replaced. The action card takes the ladder's
  safety-locked hue — the mockup paints it lime at the floor, and the floor is
  calm slate. Caught a reassuring green I had introduced mid-implementation.
- **Loading** `9820028` — the run now finishes before the result appears.
  ~33.5s over a `TweenSequence`, six stages ticking against the percentage,
  parked at 99 with a waiting state if the network runs long. An EMERGENCY and
  reduce-motion cut straight through. `health_check_ceremony_test.dart` pins
  all four cases.

## 2026-08-04 — home and the AI Health Check flow

- **AI Health Check** `6eb63e5` — the four-screen guided flow
  (`ai_health_check_start` → `photo_analysis_upload` → `symptom_selection` →
  `ai_analysis_loading`), sharing one chrome: circled header, node rail,
  disclaimer strip, pinned action. A gallery pick runs the camera's own
  pipeline (EXIF/GPS stripped in an isolate, presigned PUT) rather than round
  it; the offline emergency router runs on the assembled description before any
  network call. The loading percentage is elapsed-time progress, asymptotic —
  never confidence, which is never rendered. Copy departures: the mockup's
  "allergies", "signs of infection" and "Low risk" all name or grade things the
  product must not claim.
- **Home** `3881f38` — rebuilt to mockup `010`: brand bar, pet rail, greeting,
  hero, quick actions, two insight columns, pill grid, stat strip, quota line.
  The hero's "Buddy is doing great! / No health issues detected" is replaced by
  the last-check line — both are all-clears `safety_copy_test` bans — and the
  "Health Score" ring becomes a record-completeness metric under D-2. Fixed
  three responsiveness defects the two-column layout exposed: `WalkCard` and
  `CommunityCard` collapsing in a narrow column, an `IntrinsicHeight` that
  could not measure a `LayoutBuilder` and blanked the block, and
  `PawPillButton` ellipsising half the grid.
- **Onboarding** `295fff5` — the CTA is pinned over a fade strip with the
  content scrolling beneath, so it is reachable on the first frame of all eight
  pages; the footer measures itself, and page-level gaps scale with the
  viewport. Artwork and type never scale.

## 2026-08-03 — onboarding rebuilt against the mockups

- **009 + 008** `76b9988` — the add-pet page (species photo gallery, two-column
  record card, photo well + dashed upload, benefits, privacy) and the welcome
  page (success crest, celebration hero in a paw field, spark rule, four tiles,
  PRIVATE BY DESIGN). Two blockers in the pre-auth flow found by walking it:
  the add-pet step could not be passed (`create` reads `currentUser!.id`, and
  onboarding now runs before auth) — fixed with `PendingPet`, flushed on the
  first authenticated frame; and finishing looped back to the app-open screen —
  onboarding now exits to `/auth-gateway`. Also caught a System A leak: the
  shipping `SpeciesChip` was rendering its selection in lime on navy.
- **007 + 006** `e61aab5` — the two assistant pages, one per mockup. The flow
  had collapsed them into one and invented an activation page to fill the gap,
  so neither was on screen; it is now 1:1 with `002`–`009`, matching the
  `Step N of 8` the mockups print. `AssistantStage` sizes from the card row,
  not a fixed box — three cards a side are taller than the device.
- **005 + 004** `699f503` — the glass compare cards with the `≠` light
  collision composited in `BlendMode.screen`, and the diary composition (rail
  with a dotted spine, device with a live timeline, callout bubble, the pair
  bleeding off the right edge). `onb-hero-dog-kitten-cutout` turned out to be a
  rendered checkerboard baked into RGB — keyed, eroded and feathered.
- Type re-measured off the references: display 28/30, deck 13, page gutter 18.
  The mockups are AI-rendered pictures, so their ~8-10dp body copy is not
  reproducible on a handset; layout is matched exactly, type sits ~15% above.

## 2026-08-03

- **Q** — Full gate set (analyze, 432 tests, disclaimers, placeholders, Edge
  node tests) + device matrix on the Redmi release build.
- **P** `b619336` — System A isolated on onboarding and sign-in.
  `system_isolation_test.dart` pins the boundary; it became load-bearing once
  the accent palette was repointed to lime.
- **J–O** `5ecff02` — Accent palette repointed to System B. One change migrated
  ~120 call sites across memories, encyclopedia, walks, reminders, community,
  premium and account. `PawFeatureRow` icon tiles resolve through `PawTone`.
- **I** `dc84714` — System B declared at the app root. Pushed routes sit above
  the shell's scope, so every detail screen had still been resolving to
  `legacy`. Assistant audited clean; V-12 / V-23 pinned.
- **H** `fb2c6f6` — Photoreal species art wired; `AppAssets.species()` had
  pointed at an empty folder since M2, so every chip and avatar silently fell
  back to emoji. Primary CTA and `secondaryContainer` migrated.
- **G** `76e3ab4` — App-wide System B `ColorScheme`. V-22 provenance markers in
  the exported health report and vet prep pack.

## 2026-08-02

- **F** `4d272e2` — Owner decision D-1 pinned on the emergency surfaces. A third
  rule-4 violation found in `emergency_hub` that the safety review had not
  catalogued.
- **E** `6b5f7da` — `safety_copy_test.dart`; `PawBackground` follows
  `PawSystemScope`.
- **D** `00924e7`, `9d846d9` — Home onto the component library; `PawCard`
  migrated all its consumers.
- **C** `6e45e39` — New navigation shell; Emergency a permanent destination
  (resolves C-7 / V-24).
- **B** `e88a3b9` — 13-primitive component library; a 42 dp touch target fixed.
- **A** `2eac156` — Both colour ramps as tokens; light-mode lime corrected to
  `#4D7C0F` after measurement.
- **0** `d17f02a` — 291 production assets sliced from 110 placeholder-named
  contact-sheet plates; pipeline vendored at `mobile/tool/asset_pipeline/`.
