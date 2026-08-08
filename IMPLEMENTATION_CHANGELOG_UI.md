# UI Implementation Changelog

Chronological record of the UI migration (Phase 0 + A–Q). Detail lives in
`UI_IMPLEMENTATION_ROADMAP.md`; rationale in
`PAWDOC_UI_IMPLEMENTATION_FINAL_REPORT.md`; resume state in
`memory/UI_PROGRESS.md`.

## 2026-08-08 (later) — vet prep, the health report and the four premium surfaces

Branch `ui-batch-t-prep-report-premium`, cut from `main` after PR #99 merged
(`b7559b9`). **53 of 58 mockups implemented. 968 tests** (was 852).

| Mockup | Where it lives | Commit |
|---|---|---|
| `prepare_for_vet_visit` | `prep/vet_visit_prep_screen.dart` + `prep/vet_visit_prep.dart` (new model) | `f1acc80` |
| `pdf_health_report_preview` | `health/health_report_preview_screen.dart` + `health/report_preview.dart` (both new) | `f1acc80` |
| `premium_home` | `monetization/premium_home_screen.dart` (new) | `afc622d` |
| `subscription_plans` | `monetization/paywall_screen.dart` (rebuilt in place) | `afc622d` |
| `upgrade_benefits` | `monetization/upgrade_benefits_screen.dart` (new) | `afc622d` |
| `usage_limits` | `monetization/usage_limits_screen.dart` (new) | `afc622d` |

New shared modules: **`monetization/entitlements.dart`** (the audited
catalogue every premium surface renders — four screens, one source of truth),
**`monetization/premium_sections.dart`** (hero, feature strip, feature grid,
comparison table, usage meter, band, FAQ, honesty note, `PremiumTone`),
`monetization/usage_state.dart`, `monetization/subscription_state.dart`,
`prep/vet_visit_prep.dart`, `health/report_preview.dart`.
Deleted: `monetization/paywall_copy.dart` (orphaned by the rebuild).

**Product-truth removals** — the four monetization plates are the most
claim-dense in the set, and almost nothing they sell exists: chat with
verified veterinarians, "premium tools made by vets", a 7-day money-back
guarantee, "4.9/5 from 10,000+ reviews", three tiers at three invented
prices, 1 GB of free storage, advanced analytics, priority/dedicated support,
early access, multi-user access, a 15-pet ceiling. The `pdf_health_report_preview`
plate adds an owner-contact panel, "all vaccinations are up to date", "Lab
Results · Normal", "Allergy · Severity: Moderate", named clinics and
veterinarians, and a "Scan to verify" QR. `prepare_for_vet_visit` adds a
Severity meter. All gone; see each screen's header table for the reasoning.

**Defects found and fixed:** `Purchases.getOfferings()` hangs on an
unconfigured SDK (both offering reads now guarded + bounded — the same defect
class as the Redmi `getCustomerInfo()` hang); analytics was awaited before the
price read; `HealthNumberedHead` split its free space between a `Spacer` and
its title's `Flexible`; `usage_limits` checked `isLoading` before `hasError`,
which Riverpod 3's retry makes unreachable; a RenderFlex overflow in the
comparison header at the em-square test font.

**Parity tests added:** `entitlements_test` reads `free_tier.mjs`,
`assistant_chat.mjs` and `quota_gate.mjs`; `pdf_report_preview_test` reads
`_shared/pdf_report.mjs` and `generate-pdf-report/index.ts`. Both fail if the
Dart copy drifts from the server that enforces or builds it.

## 2026-08-08 — community and emergency: six screens

Branch `ui-batch-s-community-emergency`, cut from `main` after PR #98 merged
(`35a6ff5`). **47 of 57 mockups implemented. 852 tests** (was 784).

| Mockup | Implementation | Commit |
|---|---|---|
| `first_aid_guide` | `emergency/first_aid_guide_screen.dart` (new) | `5331ad9` |
| `emergency_hub` | `emergency/emergency_help_screen.dart` (rebuilt) | `5287501` |
| `nearby_pet_owners` | `community/nearby_screen.dart` (new) | `895c000` |
| `community_feed` | `community/community_home_screen.dart` (rebuilt) | `197ba70` |
| `community_post_detail` | `community/community_chat_screen.dart` (rebuilt) | `197ba70` |
| `create_post` | `community/create_post_screen.dart` (new) | `197ba70` |

New shared modules: `emergency/emergency_sections.dart`,
`community/community_sections.dart`, `test/support/fake_community.dart`.

**The community has no posts table.** It is `community_profiles`,
`community_connections`, `community_messages`, `walk_proposals` and
`community_reports` — no posts, reactions, follows, groups, media or presence,
and location only as a five-character geohash *cell*. Owner decision this
session: **map the three post mockups onto the real graph** rather than ship
inert shells. Feed → the community home; post detail → the member and the real
1:1 thread, with the reference's details strip carrying a real `walk_proposal`;
create post → the profile composer. Post-only controls keep their place and say
*Soon*.

**Sixteen blocks across the six references were not built.** The emergency pair
lost AI Triage, the "At Risk Pets / Needs Attention" row, Emergency Transport,
Share Records, the fabricated 24/7 clinic directory, the Heat Alert strip, the
"High Priority" badges, the relevance sort, the invented read times and
"Available 24/7". The community trio lost reaction/comment/share/save counts,
follows, hashtags, polls, stories, groups, presence, the live map with people
pinned at tenths of a mile, and — the one that mattered most — the **verified
veterinarian** answering a health question in-feed.

Defects found and fixed: a `FutureBuilder` reading `snapshot.data ?? []` that
rendered a failed lookup as an empty community; controllers disposed while
their sheet was still animating out; `community_screens_test` never setting a
handset surface, so every tap below the 600px fold silently missed; a 35px
proposal-row overflow that exposed; and on the device, a white halo on the
first-aid glyph assets, a run-together category rail, full-width species chips
(a `Container` with an `alignment` expands into a `Wrap`'s loose constraints),
and Quick Action subtitles clipping at a 1.3× text scale.

## 2026-08-07 (evening) — memories, walks, baseline, breeds: seven screens

Branch `ui-batch-r-pets-memories`, **rebased onto the squashed `main`**
(`git rebase --onto origin/main e6effd6`) now that PR #97 is merged. **41 of 57
mockups implemented. 784 tests.**

**The batch where the references stopped being merely unsupported and started
being unsafe.** Three of these seven print claims that could change what an
owner does about a sick animal. Each is enumerated below with what shipped
instead.

- **`add_memory`** `b5b4647`. The journal's "+" opened a half-height frosted
  sheet; a sheet cannot hold six numbered cards, a four-stop rail and an upload
  run. **The reference's "up to 10 photos" is real**: `pet_memories` holds one
  `storage_key`, so a pick writes one entry per photograph sharing the pet,
  date, title and note — the review step says so before anything is written,
  the strip drags to reorder, and `allowedPhotoCount` (pure, tested) checks the
  free allowance against the *whole batch*: two slots left against a five-photo
  pick takes two, rather than failing the batch or silently writing five.
  Four things the schema cannot hold keep their control and say *Soon* —
  video, a time of day, tags, and Family/Public sharing. **Private here is a
  description of the table, not a preference**, and the tile says so.
  *On the reference's own step rail:* the plate highlights step 1 · Media while
  showing sections 1–6, and its button reads "Next: Add Tags" — step 3. The
  render stacked Media and Details onto one canvas; the cards are dealt across
  the two steps the rail names, so the button that says "Next: Add Tags" is the
  one that goes to the tags.
- **`search_memories`** `149ac4d`. A new surface: the gallery filters the book
  you are looking at, this searches every pet's at once. **Everything the
  reference counts, this counts.** "128 memories found" is the number of rows
  that matched; each Quick Search chip carries the tally its own terms hit
  (a chip that finds nothing says *none yet* rather than inventing 24);
  "Most Relevant" is a real ranking pinned by `memoryMatchScore`.
  **The location filter cannot exist** — EXIF and GPS are stripped on the
  device before upload, as a rule and not a setting. The slot keeps its
  position and holds the owner's own hearts; the More Filters sheet states the
  rule, and a test asserts no location string reaches the screen.
  Recent searches are device-local, capped at six, de-duplicated
  case-insensitively, and only remembered once a query is *acted on* — storing
  every keystroke fills the list with the prefixes of one word.
- **`smart_walks` + `weather_walk_advisor`** `450d356`. Two screens, one
  commit: they share `walks/walk_sections.dart` and each navigates to the
  other. The references brand a **pure function** as "AI Walk Suggestion" and
  prescribe exercise — "up to 60 minutes a day is ideal for heart health and
  weight control", "Estimated duration 30–45 min", "Ideal distance 3–5 km",
  "a water break every 15–20 minutes", "215 kcal burned". All gone;
  `kWalkDurationDisclaimer` sits where they were. What remains is weather,
  scored on the device by `scoreWalkHour` — the comfort bands, the hour-by-hour
  rail, and a five-day outlook built by `dailyWalkOutlook` (which needed
  `parseMetCompact` to keep 120 entries rather than 48 — same request, more of
  the response read). There is **no walk tracking**, so the live-walk card, the
  log and the milestones keep their place and say *Soon*. The reference's
  badges count kilometres and calories; these count the owner's habit.
  `WalkBand`'s four tones carry their own ladder guard — the reference paints
  its bands amber and orange, which land on the MONITOR hue.
- **`know_your_baseline`** `dbbdcd3`. **The most contract-hostile reference in
  the set.** It prints five vital signs the app has no sensor for, captioned
  *"Your Pet's Normal Range"* — and two of them, **60–100 bpm** and
  **38.0–39.2 °C**, are real published reference ranges for a dog. Printing a
  textbook range under a pet's name and calling it theirs is medical content
  this product has no standing to publish; an owner who then counts 105 bpm at
  home draws exactly the conclusion PawDoc exists to route to a vet. What
  ships is the owner's own filing — the range *their records* span, how long
  they have kept them, where the gaps are — computed by `health/baseline.dart`,
  pure and tested in fourteen cases. A single weight is a *reading*, not a
  range: `hasRange` needs two, because drawing one point as a band is the first
  step towards drawing a normal.
- **`breed_encyclopedia` + `breed_detail`** `82d2cf6`. Two screens, one commit,
  sharing `encyclopedia/breed_sections.dart`. Both print "Common Health
  Conditions — Hip Dysplasia · **Risk: Moderate**" with a filled dot meter,
  five deep, on a page whose most likely reader owns that breed. The catalogue
  already held the honest version: `health_notes` were authored hedged from the
  start, and they ship under **What Vets Watch For** with no grade at all.
  Six invented fields dropped (Height, Coat Length, Colors, Breed Group, AKC
  Recognition, FCI Group), plus a "Popularity #3 · AKC Rankings" badge and four
  star ratings nobody rated. Where the reference repeats detail content under
  an index's search bar, the index shows the catalogue — because a search with
  nothing to filter is not a search.

### Safety departures, all layout-preserving

| Mockup | Shipped |
|---|---|
| "Resting Heart Rate · 60 – 100 bpm · Your Pet's Normal Range" | **nothing** — the tile keeps its place and says *Not tracked*, naming the reason |
| "Body Temperature 38.0 – 39.2 °C", "Respiratory Rate 15 – 30", "Activity 40 – 90 min/day" | the same |
| "Baseline Strength · 92/100 · Excellent" | the Care Score (D-2), computed identically to the timeline's |
| "Everything looks good! … stable and well within his normal range" | what the record holds, counted |
| "Alerts Triggered · 0" | gone — it implies monitoring. The page says outright that there is none |
| "Consistency · 92%" | the longest gap, in days |
| "Great consistency! Keep up the good work!" | observations, counted; a test bans praise vocabulary |
| "Most active time · 5 PM – 8 PM" | gone — nothing tracks activity |
| "View Warning Signs" | **Start a health check** — an ungated symptom list is the one thing this product must not hand out |
| "Hip Dysplasia · Risk: Moderate" ×5 with dot meters | the catalogue's hedged notes, no grade, under the standing line |
| "Popularity #3 · AKC Rankings" / "FCI Group 8" / "AKC Recognition 1925" | gone — citing a registry we do not have is fabrication |
| "Trainability ★4.7" / "Good With Kids 5/5" / "Watchdog Ability 2/5" | the two levels the catalogue authors |
| "Nutrition · High quality dog food" | the coat description |
| "With proper care… a long, healthy and happy life" | the range, and that it is not a prediction |
| "AI Walk Suggestion" | not AI — `scoreWalkHour` is a pure function |
| "60 minutes a day is ideal for heart health and weight control" | gone |
| "Estimated duration 30 – 45 min" / "Ideal distance 3 – 5 km" | the kindest hours, the ground, the water, the sun — over the vet's-call line |
| "Water break every 15 – 20 minutes" | "Carry water and offer it whenever you stop" |
| "215 kcal" / "Calorie Hunter 312/500" | gone — it needs weight, gait and metabolism |
| badges for "Walk 50 km" / "100 km" | milestones about the owner's habit |
| "All Locations" + a place per result | the owner's own hearts; the sheet states the EXIF rule |
| "Family" / "Public" memory sharing | drawn, *Soon*; every row is RLS-scoped |
| "Take Breed Match Quiz" | the card, *Soon* |

### Extracted, not duplicated

Into `health_sections.dart`: **`HealthStepRail`** (26dp circles on the
reference's own centres — 23dp inset, four equal columns, 66/153/240/327 on a
393 screen; the whole column is the tap target, because a label with no hit box
only fails on a real thumb), **`HealthNumberedHead`**, **`HealthCountedField`**,
**`HealthDashedTile` + `HealthDashedPainter`** (which **collapsed two private
dashed-rectangle painters** that had already been written twice), and
**`HealthDropPill`** (which replaced `memories_screen`'s private
`_DropButton`). `HealthSearchField` learned `onSubmitted`.

Five new shared modules: **`pets/pet_pick_rail.dart`** (the tall
portrait-over-name rail, lifted out of `add_memory_screen` where it was
private, now serving two screens), **`memories/memory_search.dart`**,
**`walks/walk_sections.dart`**, **`health/baseline.dart`**,
**`encyclopedia/breed_sections.dart`**.

### Six shipped defects fixed

1. **`HealthPrimaryCta` accepted an `icon` and drew a hardcoded `plus`** — the
   journal's "See Premium" button rendered its crown argument as a **+**. It is
   honoured now, and the CTA learned a trailing glyph and a disabled state.
2. **The home walk card rendered one character per line.** Home became a
   two-column layout in an earlier batch and only the `WalksInitial` branch was
   adapted; the permission state gave its copy ~10dp and the ready state ~40.
   All four states go through one `_GlyphBodyAction` now.
3. **A missing breed asset threw.** Five bare `Image.asset` call sites, so a
   renamed file would have taken the page down rather than left a gap.
   `BreedPhoto` falls back to a species glyph.
4. **The Care Score read 29 on the baseline screen and 43 on the timeline** for
   the same pet — this screen passed `hasReminder: false` instead of watching
   the provider. Two surfaces printing a different Care Score is how a number
   stops meaning anything.
5. **The health module menu overflowed by 132px** once a seventh row was added;
   its sheet was not scrollable.
6. **A three-button header ellipsised "Memories Gallery."** The search entry
   moved to the toolbar row, where there is room.

### The safety defect the device found

The five-day outlook scores a day by its **best** hour, so a 34 °C Sunday read
**"Ideal"** over "34° / 26°" — an invitation to walk at noon on a day whose
only kind hour was at six in the morning. `WalkDayOutlook` carries `bestHour`
now and the tile prints "90 · 06:00": the band answers *whether*, the hour
answers *when*, and without the second the first misleads.

### Layout lessons

Two more departures joined the documented list: `search_memories` sets its four
filter pills **two-up** (each is a *value* display — "All Types" now, "Photos"
later — and an 87dp pill leaves ~50 for the label once the glyph and chevron
are paid for, which "Hearted only" does not fit), and `add_memory` deals the
reference's six cards across two steps.

Also learned: **a horizontal rail is lazy** — off-screen chips are not in the
element tree, so a widget test must drag the rail before tapping the last ones.
And the `IntrinsicHeight` two-line rule applies inside a fixed-height rail as
well: the walk milestones and the baseline factor tiles both needed an explicit
slot.

### And the adb lessons

`am start` while `flutter run` is attached opens a second activity with no
engine and renders blank white. A `&&` chain that aborts on a missing
`/tmp/flutter.pid` silently skips the relaunch. `keyevent 4` closes the IME on
the first press but **pops the route** when no IME is up. And the screen sleeps
and the notification shade steals focus unless `svc power stayon true` and a
raised `screen_off_timeout` are set first.

## 2026-08-07 (later) — pets and memories: seven screens

Branch `ui-batch-r-pets-memories`, stacked on `e6effd6` because PR #97 could
not be merged (author cannot self-approve; `--admin` refused). **34 of 57
mockups now implemented. 691 tests.**

- **`reminder_detail`** `c56c863`. A reminder had no page — tapping a row
  opened the edit form. Now it has one. Two `reminders` columns that had never
  been read fill it: `created_at` is "Set on" and the first history entry,
  `notification_sent_at` is the delivery status and the second. The
  notification time is read from `LocalNotifications.reminderHour` rather than
  repeated as a literal, so the screen cannot drift from the scheduler.
  Postpone rewrites `due_date` through the repository, which reschedules the
  notification — device-verified. The mockup's dose, repeat cadence and
  six-occurrence schedule have no column: the repeat and lead-up controls keep
  their place and say *Soon*, and the rail plots the pet's real upcoming
  reminders with this one lit. "Mark as taken" is device-local and the screen
  says so twice; the key is the *due* date, so moving a reminder drops its tick
  and clears the stale key.
- **`pet_profile`** `b6d8063`. **A screen that never existed** — "View Profile"
  pushed the *edit form*. Hero, a five-tab rail, Basic Information, four
  counted record cards, About, the vet card and the family banner. The most
  contract-hostile mockup since the result screens: it grades the animal four
  times (§ safety below). The vet card offers a maps search because there is no
  saved-vet table and inventing a practice would put a fake clinic on a health
  record.
- **`edit_pet`** `d707c31`. `PetFormScreen` rebuilt in place — the last legacy
  Material screen in the pets area. Five of the mockup's fields have no column
  and nowhere honest to go (folding a microchip number into `medical_notes`
  would push it into the vet report as a clinical note), so each keeps its
  place, renders as a real control and says *Soon*. Delete is the existing
  **soft** delete and the confirmation says the record survives.
- **`manage_multiple_pets`** `c817d4a`. `PetsListScreen` rebuilt in place, with
  search, four sort orders, and both layouts — all client-side and pure. Every
  per-card action switches the active pet first, because the modules it opens
  read `activePetProvider`. It also learned `embedded`, like
  `HealthHistoryScreen`, because it now draws the bottom bar itself.
- **`pet_statistics`** `669592e`. New screen. Pet rail, overview tiles with
  per-type sparklines, the trend chart, the Care Score dial, a donut breakdown,
  category bars, highlights and a pet comparison. `PetStats` is a pure factory
  over `List<TimelineItem>`, so the arithmetic is unit-tested without pumping a
  widget.
- **`memories_gallery`** `4a892bb`. Rebuilt in place. Pet rail with **All Pets
  merging every pet's book**, search, type and order controls, the Highlights
  row and month sections. All six existing `memories_screen_test` assertions
  pass untouched — every key survived the rebuild.
- **`memory_detail`** `2029615`. `MemoryViewerScreen` rebuilt in place. The
  "1 / 8" counter and its arrows turned out to be genuinely available: they are
  the real position in the pet's book and really step through it. "More from
  this day" lists the memories sharing the date.

### Safety departures, all layout-preserving

| Mockup | Shipped |
|---|---|
| "Health Score · 92 · Excellent" (×4 screens) | the Care Score, record completeness, banded by `careBand()` (D-2) |
| "Family Health · Excellent" over three pets | records on file, counted |
| "Vaccinations 12/12 · Completed · Up to date" | how many are on file |
| "Allergies · 2 · Known" | the owner's own notes, marked as theirs (V-22) |
| "Conditions · 0 · None · Great!" | **gone** — an all-clear, and the literal string `safety_copy_test` bans |
| "Health Score Trend", rising 78 → 92 | **Records Over Time** — what was logged, never how an animal is doing |
| "All good! Keep it up" / "Great Job! …improved by 14 points" | gone |
| "Consider dental check-up. Regular dental care improves overall health." | **gone** — recommending a procedure is veterinary advice |
| "Expenses · ₺2,450 · Total Spent" | the tile, marked *Soon*. There is no money in this product |
| "AI Highlight · Captured Buddy's playful spirit perfectly" | **gone** — a model reading a mood off a photograph, on the one surface documented as human content only |
| "Location · Kent Park, Eskişehir" + map | the privacy rule: PawDoc strips GPS on the device before upload |
| "Dr. Ayşe Yılmaz · PawCare Veterinary Clinic" | a maps search |
| "Blood Type: DEA 1.1 +" / "N/A" | dropped from the card; *Soon* in the form |
| "Primary Pet" | **Active** — the app has an active pet, which is a different claim |
| Delete / Skip in the EMERGENCY red (×3) | `HealthTone.gold`; the confirmation carries the weight |
| a video scrubber, duration, size, resolution | Type, taken on, added on, stored |

### Extracted, not duplicated

`health_sections.dart` grew from twenty blocks to thirty-one:
**`HealthActionPill`** (out of `HealthSectionHead`'s boxed action, whose glyph
was hardcoded), **`HealthInfoGrid`/`HealthInfoCell`**, **`HealthSettingRow`**,
**`HealthSearchField`** (out of `conversation_history_screen`),
**`HealthSparkline`** (out of `result_sections.dart`), and **the whole form
kit** — `HealthFieldShell`, `HealthClearButton`, `HealthTextField`,
`HealthPickerField`, `HealthChoiceField`, `HealthNotesField` — out of
`health_event_form_screen.dart`, where all six were private. `HealthStat`
gained an `onTap`; `PetModuleAppBar` gained `subtitleTrail` and `actionsWidth`.

Elsewhere: **`LocalTickLog`** (`core/`) is the device-local tick store, with
`DoseLog` delegating to it and two new consumers — reminder ticks and memory
hearts. **`careBand()`** joined `careScore()` in `home_sections.dart` so three
surfaces cannot spell a band differently. **`healthEventIcon()`** moved to
`health_event.dart` beside `healthEventLabel`, and `ReminderCategory`'s tint
became `reminderTint` in its screen file — both moves made **specifically to
keep the `assistant → health → home → theme` dependency direction**, which the
obvious placement would have inverted. `clockTime`, `dateAtTime` and
`monthAbbrev` went into `core/dates.dart`.

### The regression the existing tests caught

The `manage_multiple_pets` rebuild dropped the **F-4 last-check chip** — fed by
`latestTriageProvider`, the only per-pet health signal on the page. Three
`pets_list_test` assertions failed immediately. It is restored on its own line,
because the name plus two chips in a ~147dp column does not fit at readable
type: the device clipped "Active" to "A…" and the test font overflowed the row
by 76px. It keeps the ladder's own safety-locked hue — the one place on that
screen where colour means a triage level, which is the meaning the ladder owns.
The same three failures also restored the identity meta's species and the warm
empty state's copy.

### Six defects the tests caught before the device

1. `HealthActionPill`'s label took its natural width under `mainAxisSize.min`,
   so "Open the vaccination manager" overflowed by 33px at the em-square font.
2. Four record cards used `CrossAxisAlignment.stretch` inside the scroll view's
   unbounded Column, handing children infinite height. `IntrinsicHeight`, as
   `HealthStatTiles` does.
3. The name-plus-two-chips overflow above.
4. **"All time" silently excluded records older than the 24-month axis cap.**
   The cap exists so the chart stays readable; letting it filter the *counts*
   meant a three-year-old vaccination vanished from a total labelled "all time".
5. A hint spelled like real data ("Golden Retriever") duplicates the value in
   the widget tree, because `hintText` stays mounted at zero opacity once a
   field is filled — a duplicate for a test, and for a screen reader.
6. `_ComparisonCard` needed its own test rather than a second `pumpWidget` with
   different overrides.

### Three the device caught

- The Care Score box clipped to "Car…" / "Jus…" at its 94dp share. Restructured
  so the label gets the box's full width. **Corollary worth remembering:** a
  `Flexible` with a flex share is *capped* at that share, so a chip given
  `flex: 2` truncates even when its sibling left slack.
- Every overview tile on `pet_statistics` plotted the same total-records
  series, so the "Medications" sparkline was drawing all records. `PetStats`
  keeps a per-type series now.
- `edit_pet`'s portrait rendered `LivingPetAvatar` directly, whose no-photo
  fallback is the cartoon paw pal — so a pet with no photo looked like a
  different animal there than on its own profile. It uses `PetPortrait` now.

### And one adb lesson, the hard way

`input keyevent 111` (ESC) dismisses a **bottom sheet**, not just the IME — it
threw away a half-filled memory form. `keyevent 4` (BACK) closes the IME on the
first press. Separately, a five-tap blind chain drifted onto the wrong screen;
screenshot between steps unless the path has already been walked once.

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
