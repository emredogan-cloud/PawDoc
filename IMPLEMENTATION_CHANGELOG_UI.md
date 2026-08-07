# UI Implementation Changelog

Chronological record of the UI migration (Phase 0 + A–Q). Detail lives in
`UI_IMPLEMENTATION_ROADMAP.md`; rationale in
`PAWDOC_UI_IMPLEMENTATION_FINAL_REPORT.md`; resume state in
`memory/UI_PROGRESS.md`.

## 2026-08-07 — the health module: six screens

- **`conversation_history`** `f6715b6`. Replaces the half-height sheet the
  assistant's History button opened. Pet header, search, topic rail, privacy
  card, threads grouped by day, statistics, clear-history — over the app's
  bottom navigation. Everything on it is real: the preview is the thread's own
  opening reply, the photo count is how many messages carry an image, the topic
  is derived from the thread's words (a filing label on the owner's question,
  never a claim about the animal), and the statistics are counted. The
  repository gained `summaries()` — one extra round trip for the page, not one
  per row — and `deleteAll()`, whose scope is the RLS policy, not the statement.
- **`health_timeline`** `1cba0e6`. Rebuilt in place, so the Health tab, the
  `/history` route and every deep link keep working. Hero with the Care Score,
  the eight-type rail, counted statistics, the dashed rail with one card per
  record, the pinned Add Event footer. The cards now go somewhere: "View
  Result" reopens the stored analysis from `full_response` (the frozen contract
  payload — same screen, no second inference), and "View Details" opens a
  record-detail sheet marked *"Entered by the owner. PawDoc did not review
  it."* (V-22), with a delete. `TimelineItem` grew the fields those need and
  leads each row with its metadata, so a medication reads "NexGard Spectra ·
  11–22 kg" with the note beneath.
- **`add_health_record`** `a8c6846`. `HealthEventFormScreen` rebuilt in place —
  every caller keeps working. The six-tile type rail with the mockup's check
  badge, the Record Details card (date + time two-up, clinic, veterinarian,
  reason, notes with its counter), the attachment gallery, the reminder switch,
  the privacy card, the Save CTA over the encryption line. One row component
  throughout; which rows appear follows the type. Attachments are real: the
  journal's media service, so EXIF/GPS is stripped in an isolate before a
  presigned PUT. The reminder switch generalises E7 to every record type.
- **`weight_tracking`** `c488dea`. New screen. Summary hero, four counted
  statistics, a chart drawn from the points (CustomPainter — kg axis, dated
  ticks, a labelled dot per entry, a 1M–all-time range selector), the record
  list, the add card, the educational footer.
- **`medication_tracker`** `9af3a54`. New screen over records that already
  existed. `medication_plan.dart` parses the sentence an owner typed ("Every 12
  hours", "Twice daily", "Every 30 days") into dose slots and **fails to
  nothing** — an unreadable schedule produces no doses rather than a guess, and
  the medicine is still listed with its text as written. Ticks are kept on the
  device, and the screen says so twice: a dose table is a migration plus an RLS
  policy plus a deploy, and a "Mark as taken" whose answer is silently
  forgotten would be worse than none.
- **`vaccination_manager`** `24205ea`. New screen. Record summary, counted
  statistics, the class filter rail, what is coming up, the history, the
  educational footer. Core / Non-core / Lifestyle is owner-selected and never
  inferred — which vaccines are core is a regional veterinary judgement.

### The shared skeleton

`health/health_sections.dart` is what all six are built from: `PetModuleAppBar`,
`PetModuleHeaderCard`, `HealthRingPortrait`, `HealthFilterChips`,
`HealthStatTiles`, `HealthRecordRow`, `HealthGlyphDisc`, `HealthPill`,
`HealthMetaBlock`, `HealthStatusBadge`, `HealthAddCard`, `HealthEduCard`,
`HealthPrivacyCard`, `HealthDangerCard`, `HealthPrimaryCta`, `HealthSheet`,
`HealthDetailRow`, `HealthSectionHead`, `HealthGroupLabel`,
`HealthRecordScaffold` + `HealthBleed`. Plus `pets/pet_switcher.dart` — one
switcher behind all six header chevrons — and `core/paw_nav_bar.dart`, which
came out of `root_shell.dart` because five of the six mockups draw the bar on a
*pushed* screen. The shell's tab index moved to `rootTabProvider`; a detached
bar selects a tab and unwinds to the shell rather than stacking a second copy.
Emergency keeps its slot (C-7 / V-24); the mockups spend it on Settings.

### Safety departures, all of them layout-preserving

The mockups grade the animal on four of these six screens. Every claim was
replaced and every card kept its position, its glyph and its density:

| Mockup | Shipped |
|---|---|
| "Health Score · 92 · Excellent" | the Care Score, record completeness (D-2) |
| "AI Skin Analysis" + "Low Risk" chip | "AI Health Check" + the action-ladder value, in the ladder's own hue |
| "Mild redness… Likely caused by licking." | the stored observation, and nothing else |
| "✓ All parameters normal" | the owner's own note |
| "Ideal Range (26.0 – 30.0 kg)" + "Ideal" badges | the owner's **own** target range, or no band at all; the badge states the change since the entry before |
| "Great job! Buddy is within the ideal weight range." | what the record shows, and that a healthy weight is the vet's call |
| "Medication Adherence · 96% · Excellent" | counted from doses actually ticked; **null, not zero**, when nothing was scheduled |
| "Give medications with food if recommended" | what the label and the vet said, unchanged by this list |
| "Protection Status · Excellent · Fully protected" | what the record holds, and how much of it carries a next date |
| "100% · On Schedule · Great job!" | how many are past their due date, with "Ask your vet" |
| "2h 14m · Total time saved" | messages, counted |
| type tile "AI Analysis" | **Weight** — an AI check belongs to the Check flow, where the emergency override, the quota rules and the action ladder apply |

### Three pre-existing bugs this batch surfaced

1. **Every date picker in the app crashed, on every device, at the default font
   size.** `app.dart`'s UX-03 clamp used `TextScaler.clamp(min: 1.0, max: 1.6)`,
   which returns a scaler *carrying* those bounds; Material's
   `_DatePickerHeader` re-clamps to `min(currentScale, 1.6)`, which at a system
   scale of 1.0 is a scaler whose min and max are both 1.0 — and
   `_ClampedTextScaler` asserts `maxScale > minScale`. `pawTextScaler` now
   returns the system scaler untouched when it is in range and a plain linear
   one when it is not. **The test needed a `SystemTextScaler` stand-in**:
   `TextScaler.linear` overrides `clamp` to collapse into another linear scaler,
   so it can never reproduce the bug — the first version of the test passed
   against the broken code.
2. **The weight trend drew backwards.** `postgrest`'s `order()` defaults to
   *descending*, so a bare `.order('event_date')` returned newest-first while
   every consumer read oldest-first. The vet-prep sparkline ran right to left
   and this screen showed the oldest entry as the current weight.
3. **`ResultScreen` stamped every summary "Generated just now"** — a lie the
   moment the timeline could reopen a month-old record. It takes a `generatedAt`
   now.

### Layout lessons, all found by the widget tests before the device

Two `Flexible` children in one `Row` split the free space evenly, which
squeezes a name that had room; making the neighbour fixed overflows the row
under the em-square test font. Weighted shares (3:2, 5:4) are the fix, and it
came up three times — the timeline card's action row, the record row's title
and chips, the conversation row's footer. Separately: inside an
`IntrinsicHeight` a `Text` reports its *unwrapped* single-line height, so a
statistic label wanting two lines is silently clipped to one; the slot has to
be an explicit `SizedBox`.

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
