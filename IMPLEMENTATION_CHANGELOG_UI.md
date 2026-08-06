# UI Implementation Changelog

Chronological record of the UI migration (Phase 0 + A–Q). Detail lives in
`UI_IMPLEMENTATION_ROADMAP.md`; rationale in
`PAWDOC_UI_IMPLEMENTATION_FINAL_REPORT.md`; resume state in
`memory/UI_PROGRESS.md`.

## 2026-08-06 (later) — the assistant trio

- **`ai_assistant_home` / `ai_assistant_chat` / `ai_message_actions`**
  `aae4ebe`, device pass `9f47ee1`. One route, two surfaces: the hub while
  `chat.isEmpty`, the conversation once a message exists, with the third
  mockup's sheet hanging off every reply. Nineteen presentation blocks were
  extracted into `assistant/assistant_sections.dart` — app bar, brand pill,
  paw badge, halo portrait, hero, opener row, continue card, topic tiles,
  glance card, premium strip, composer, disclaimer, pet bar, privacy strip,
  day chip, both bubbles, the helpful pill, the suggestion rail and the action
  sheet.
- **Everything the sheet offers is real.** Copy → clipboard; Save to Diary →
  the health-event form with a new `initialNotes` prefill; Share → the system
  sheet; Create Reminder → the reminder form; Report → the contact page;
  Regenerate → a new `ChatController.regenerate()` that re-asks *through*
  `send()`, so the emergency router, the quota and the server checks all apply
  again. Helpful / Not Helpful are session-local and the copy does not pretend
  otherwise — there is no assistant-message feedback table.
- **Copy departures, layout preserved.** "AI Vet Assistant" → "Your everyday
  pet-care companion" / "Everyday pet care · not a diagnosis" (V-23). "Why is
  Buddy itching?" → "Daily routine?" (V-12). "Health & Symptoms" → "Health &
  Records", because the assistant is not a second triage entry point and a
  symptom belongs in the Check flow. "Health Score · 92 · Excellent" → the
  Care Score from record completeness (D-2). Energy / Appetite / Mood /
  Activity keep their rows, marked *Soon*. And the action grid keeps the
  mockup's eight colours but not two of its choices: it paints Create Reminder
  in the MONITOR amber and Report in the EMERGENCY red, and the ladder's hues
  are safety-locked against decoration — `AssistantTone` holds the substitutes
  and a test pins the separation.
- **Four defects.** Two the widget tests caught first: the View Details pill
  and the premium CTA both overflowed their rows, because in `flutter_test`
  every glyph is a full em square — which is the large-text case that would
  have broken on a real handset. Two the device caught: the hero pet was a
  hard-edged photograph (`BlendMode.screen` was the obvious tool, and useless
  — the species cast is edge-to-edge fur with no black to drop out, so it is a
  circular feathered mask instead), and the pet/More menus were opened
  transparent for their rounded corners and then never drew a panel.
- Also learned, and now written down in the resume guide: widget tests on a
  tall scrolling screen must set a handset surface, or everything below the
  800×600 default fold is never built and the assertions pass vacuously.
- `careScore` moved from `home_screen.dart` to `home_sections.dart` — three
  surfaces draw the same D-2 dial now.

## 2026-08-06 — the emergency result, and filling the result screens out

- **Emergency result** `102c6f3` — built to `ai_analysis_result_emergency`
  under owner decision **D-7**, which authorised rebuilding the four sections
  rule 4 had kept off the screen. Rewritten, never copied: "Care Priority ·
  Immediate" for the risk grade, "Why we're flagging this" for the AI
  conclusion list, "Next step · Immediate Veterinary Assessment" for the named
  concern, "Review Status · Needs Immediate Attention" for the score dial.
  D-7's scope is the result surface only — the offline red button stays
  model-free. The gate, the paywall bypass and the zero-motion guardrail are
  unchanged. The chrome learned a `tint` so the same components run in red.
- **Low-risk / monitor result** `0715b3c` — the blocks whose content could not
  ship had been reduced to plain lists, which read thinner than the reference.
  The left list card took the mockup's weight (lead line, pill, list), the
  missing "When to see a vet?" strip was added, the reminder confirmation card
  replaced a greyed-out button, and the Care Score and trend sparkline now come
  from real data. The sparkline plots checks *logged*, not severity — a line
  that trended better or worse would be a graded verdict drawn from nothing.

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
