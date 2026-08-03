# UI Implementation Changelog

Chronological record of the UI migration (Phase 0 + A–Q). Detail lives in
`UI_IMPLEMENTATION_ROADMAP.md`; rationale in
`PAWDOC_UI_IMPLEMENTATION_FINAL_REPORT.md`; resume state in
`memory/UI_PROGRESS.md`.

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
