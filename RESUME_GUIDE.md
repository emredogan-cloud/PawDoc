# RESUME_GUIDE

**Read this first.** It is written so a fresh agent can continue in minutes
without asking questions.

**Last updated:** 2026-08-07 (evening) · **Branch:** `ui-batch-r-pets-memories`
**Head:** `82d2cf6` · **Gates:** `flutter analyze` clean · **784 tests** green ·
`verify-disclaimers` PASS

---

## 0 · State of the branch

PR #97 **merged** (squash, `2a1cc11`). This branch was rebased onto it —
`git rebase --onto origin/main e6effd6` — and force-pushed. It now sits
directly on `main` with **thirteen** commits and no stacking. Nothing is
blocked.

```
82d2cf6  Breed Encyclopedia and Breed Detail rebuilt against their mockups
dbbdcd3  Know Your Baseline rebuilt against its mockup — measured, never assumed
450d356  Smart Walks and the Weather Walk Advisor, rebuilt against their mockups
149ac4d  Search Memories rebuilt against its mockup — counted, never asserted
b5b4647  Add Memory rebuilt against its mockup — the sheet becomes a wizard
6a58f90  docs: the pets and memories batch, and the two open handoffs
3c3476e  Memory Detail · 0f61b22 Memories Gallery · 1f54f24 Pet Statistics
22c89f8  Manage Multiple Pets · aac967e Edit Pet · 09f9f65 Pet Profile
af09a28  Reminder Detail
```

**Next action: open the PR.** The branch has never been PR'd.
`gh pr create --base main`. Expect the same seven CI checks. Note that GitHub
refuses PR-author self-approval, so the merge will again need a human approval
or `gh pr merge --squash --admin`.

---

## 1 · Current phase

Rebuilding the app's screens against the reference mockups in `new-interface/`
(57 PNGs, untracked, ~93 MB). **41 of 57 mockups implemented.**

Working method, unchanged and expected to continue:

> read the reference → implement at full fidelity → `flutter analyze` →
> `flutter test` → `scripts/verify-disclaimers.sh` → hot-reload onto the
> Redmi → screenshot → compare → fix → commit → next screen.

One screen at a time, each through the full gate set before the next.

---

## 2 · Completed screens

| Mockup | Implementation | Commit |
|---|---|---|
| `0001-app-first-screen` | `onboarding/first_run_screen.dart` | `70b8aa1` |
| `000` auth gateway | `onboarding/auth_gateway_screen.dart` | `70b8aa1` |
| `002`–`009` onboarding | `onboarding/onboarding_flow.dart` + `onboarding_stages.dart` | `e26b441` … `295fff5` |
| `010-home-page` | `home/home_screen.dart` + `home/home_sections.dart` | `3881f38` |
| the four AI Health Check screens | `health_check/` | `6eb63e5` `9820028` |
| `ai_analysis_result_low_risk` + `_monitor` | `analysis/result_screen.dart` | `4ff08ef` `0715b3c` |
| `ai_analysis_result_emergency` | `analysis/emergency_result_screen.dart` | `102c6f3` |
| the assistant trio | `assistant/assistant_screen.dart` + `assistant_sections.dart` | `aae4ebe` `9f47ee1` |
| `conversation_history` | `assistant/conversation_history_screen.dart` | `f6715b6` |
| `health_timeline` | `health/history_timeline_screen.dart` | `1cba0e6` |
| `add_health_record` | `health/health_event_form_screen.dart` | `a8c6846` |
| `weight_tracking` / `medication_tracker` / `vaccination_manager` | `health/` | `c488dea` `9af3a54` `24205ea` |
| `reminder_detail` | `reminders/reminder_detail_screen.dart` | `af09a28` |
| `pet_profile` / `edit_pet` / `manage_multiple_pets` / `pet_statistics` | `pets/` | `09f9f65` … `1f54f24` |
| `memories_gallery` / `memory_detail` | `memories/` | `0f61b22` `3c3476e` |
| **`add_memory`** | **`memories/add_memory_screen.dart`** (new) | **`b5b4647`** |
| **`search_memories`** | **`memories/search_memories_screen.dart`** (new) | **`149ac4d`** |
| **`smart_walks`** | **`walks/walks_screen.dart`** (rebuilt in place) | **`450d356`** |
| **`weather_walk_advisor`** | **`walks/weather_walk_advisor_screen.dart`** (new) | **`450d356`** |
| **`know_your_baseline`** | **`health/baseline_screen.dart`** (new) | **`dbbdcd3`** |
| **`breed_encyclopedia`** | **`encyclopedia/encyclopedia_screen.dart`** (rebuilt) | **`82d2cf6`** |
| **`breed_detail`** | **`encyclopedia/breed_detail_screen.dart`** (rebuilt) | **`82d2cf6`** |

All device-walked on the Redmi Note 8 (`AYXSUKIVJVPZ7HPZ`, 1080×2340 @440dpi =
**393×851 logical** — the same size the mockups are drawn at).

---

## 3 · Remaining work — 16 mockups

### 3.1 · The two pre-auth surfaces (still the highest-visibility gap)

`000` (the auth gateway) was built but never re-walked against its mockup —
the shield overlaps the dog and the social-proof line ellipsises. The sign-in
screen is still on the legacy **light** theme. Both are the first thing every
new user sees and the only screens left on the old design.

### 3.2 · The rest of the set

`notifications`, `account_management`, `profile`, `emergency_hub` (rule 4 /
D-1 constrains it hard — read §7 first), `first_aid_guide`,
`prepare_for_vet_visit`, `pdf_health_report_preview`, `community_feed` +
`community_post_detail` + `create_post` + `nearby_pet_owners`, `premium_home` +
`subscription_plans` + `upgrade_benefits` + `usage_limits`, `ai_transparency`,
`privacy_security`.

Most already have shipping screens; the work is a rebuild against the
reference. Check `lib/src/{community,monetization,account,notifications,prep,
emergency}/` first.

---

## 4 · Reusable primitives — extend these, do not duplicate

`health/health_sections.dart` is the shared skeleton **eighteen** screens are
built from. It grew again this batch.

| Primitive | Added | Use |
|---|---|---|
| **`HealthStepRail`** | this batch | the numbered wizard rail. 26dp circles on the reference's own centres (23dp inset, four equal columns → 66/153/240/327 on a 393 screen). The whole column is the tap target, not the dot |
| **`HealthNumberedHead`** | this batch | "**1.** Add Photos" + subtitle + `(Optional)` suffix |
| **`HealthCountedField`** | this batch | a bordered box with a live `0/60` counter; single-line puts it inline, multiline beneath |
| **`HealthDashedTile`** + **`HealthDashedPainter`** | this batch | the dashed well. **Collapsed two private painters** that had already been written twice |
| **`HealthDropPill`** | this batch | the "All Types ⌄" lozenge. Replaced `memories_screen`'s private `_DropButton` |
| `HealthPrimaryCta` (+ **`icon` honoured**, **`trailingIcon`**, **`enabled`**) | fixed this batch | it accepted an `icon` and drew a hardcoded `plus` — the journal's "See Premium" rendered its crown as a **+** |
| `HealthSearchField` (+ **`onSubmitted`**) | this batch | so a screen can decide what to *remember* |
| `HealthActionPill`, `HealthInfoGrid`/`HealthInfoCell`, `HealthSettingRow`, `HealthSparkline`, the six-widget form kit, `HealthStat`, `HealthStatTiles`, `HealthRecordRow`, `HealthGlyphDisc`, `HealthPill`, `HealthMetaBlock`, `HealthStatusBadge`, `HealthAddCard`, `HealthEduCard`, `HealthPrivacyCard`, `HealthDangerCard`, `HealthSheet`, `HealthDetailRow`, `HealthRecordScaffold` + `HealthBleed`, `HealthFilterChips`, `HealthRingPortrait`, `PetModuleAppBar`, `PetModuleHeaderCard`, `HealthTone`, `kRecordGutter` | — | the rest of the skeleton |

New modules this batch:

| File | Holds |
|---|---|
| **`pets/pet_pick_rail.dart`** | `PetPickRail` / `PetPickTile` — the *tall* portrait-over-name rail (`add_memory`, `search_memories`). The **other** rail shape (portrait beside the name) stays private in `memories_screen` / `conversation_history` |
| **`memories/memory_search.dart`** | `searchMemories`, `memoryMatchScore`, `groupMemoriesByRecency`, `QuickSearch` + `kQuickSearches`, `RecentSearches`. All pure except the prefs I/O |
| **`walks/walk_sections.dart`** | `WalkBand` (+ its ladder guard), `walkBand`, `weatherGlyph`/`weatherWord`, `dailyWalkOutlook`, `walkHints`, `kWalkDurationDisclaimer`, `WalkBandChip`, `WalkScoreDial` |
| **`health/baseline.dart`** | `BaselineMeasure`, `MeasureBaseline`, `weightBaseline`, `RecordBaseline`, `baselineNotes`, `kBaselineFactors` |
| **`encyclopedia/breed_sections.dart`** | `kBreedHealthDisclaimer`, `BreedSpecies`, `breedFacts`, `breedBinomial`, `similarBreeds`, `SavedBreeds`, `BreedTraitChip`, `BreedMeterRow`, `BreedFactStrip`, `BreedHealthCard`, `BreedSaveButton`, `BreedPhoto` |

Elsewhere (unchanged): `LocalTickLog`, `careScore`/`careBand`, `healthEventIcon`,
`clockTime`/`dateAtTime`/`monthAbbrev`/`shortDate`, `showPetSwitcher`,
`PawNavBar(detached:)`, `PetPortrait`, `HomeCard`, `petAgeLabel`,
`petMetaLine` (lives in `history_timeline_screen.dart`).

**Pure functions worth reusing** (all unit-tested): `allowedPhotoCount`,
`searchMemories`/`memoryMatchScore`/`groupMemoriesByRecency`,
`RecentSearches.mergeRecent`, `dailyWalkOutlook`/`walkBand`/`walkHints`,
`weightBaseline`/`RecordBaseline.from`/`baselineNotes`, `sortBreeds`/
`similarBreeds`, `filterPets`/`sortPets`, `PetStats.from`, `sortMemories`.

**Dependency direction:** `encyclopedia → health → home → theme`, and
`memories → health`, `walks → health`. Never the other way.

---

## 5 · Architecture decisions in force

1. **Two visual systems.** System A = onboarding (navy / emerald / cyan).
   System B = the product (near-black / lime). `system_isolation_test.dart`
   pins the boundary.
2. **The mockups are AI-rendered pictures, not exported frames.** Their body
   copy measures ~7–12dp — unreadable on a handset. Match layout, spacing and
   composition exactly; set type ~15% above the naive scale. Page gutter 17dp
   (`kRecordGutter`) — the mockups themselves vary from 9 to 17, so the app's
   single constant wins.
   *Where readable type genuinely will not fit the reference's composition,
   restructure and say why in the commit* — five times so far (§5.13).
3. **Pinned footers** via `HealthRecordScaffold`, which applies the gutter per
   child so a `HealthBleed` can paint edge to edge.
4. **The bottom nav lives in `core/paw_nav_bar.dart`.** A screen that is *also*
   a shell tab takes an `embedded` flag so it does not stack a second bar.
5. **`PendingPet`** holds the onboarding pet until there is a session.
6. **Bodies are a Column in a scroll view**, not a lazy ListView.
7. **Widget tests must set a handset surface** (393×2200–3600). The default
   800×600 window means everything below the fold is never built and the
   assertions pass vacuously.
8. **In `flutter_test` every glyph is a full em square.** A `Row` that fits on
   device overflows in a test. That is a feature — it has now found **fifteen**
   real defects before the device did.
9. **Two `Flexible` children in one `Row` split the free space evenly.** Use
   weighted shares (3:2, 5:4, 4:2:2). A `Flexible` with a flex share is
   *capped* at that share, so a chip given `flex: 2` truncates even when its
   sibling left slack.
10. **Inside an `IntrinsicHeight`, a `Text` reports its unwrapped single-line
    height.** A label wanting two lines needs an explicit `SizedBox` slot. The
    same is true inside a fixed-height horizontal rail — the walk badges and
    the baseline factor tiles both needed one.
11. **`CrossAxisAlignment.stretch` in an unbounded Column hands children
    infinite height** and trips the constraint assertion. Wrap in
    `IntrinsicHeight`.
12. **`hintText` stays in the widget tree at zero opacity once a field is
    filled.** Hints are examples: "e.g. Labrador", never "Golden Retriever".
13. **Layout departures are allowed, documented, and rare.** Five now:
    `pet_statistics` stacks its chart pairs; `memories_gallery` uses a
    three-across month grid; `manage_multiple_pets` moves the F-4 chip to its
    own line; **`search_memories` sets its four filter pills two-up** (each is
    a *value* display and "Hearted only" does not fit 50dp); **`add_memory`
    deals the reference's six cards across the two steps its own rail names**
    (the plate stacked Media and Details on one canvas — its button reads
    "Next: Add Tags", which is step 3).
14. **A horizontal rail is lazy.** Off-screen chips are not in the element
    tree, so a widget test must drag the rail before tapping the last ones
    (`encyclopedia_screen_test`'s `_section` helper).
15. **The repo is hand-formatted at 80 columns and is NOT `dart format`-clean.**
    Do not run `dart format` on the repo unless the owner decides to format all
    of it.

---

## 6 · The analysis loading run — how it works

`health_check/health_check_loading_view.dart`

- A `TweenSequence` over `HealthCheckLoadingView.ceremony` (33.5s).
- Six stages tick against the **percentage**, not a clock.
- **Never held:** an EMERGENCY (instant cut) and reduce-motion.
- **Trap:** `flutter_test_config.dart` sets `disableAnimations` on the
  *binding*, and `AnimationController` scales every duration by **0.05**.

---

## 7 · Safety rules that constrain every screen

Read `CLAUDE.md` in full. The ones that bite in UI work:

- **Confidence is never rendered.** No differential, no percentages, no risk
  level, no severity grade. **Never name a condition**, never assert a cause.
- **No output terminates without an action and a timeframe**; never render
  "normal" or any all-clear.
- **The emergency surfaces** carry help contacts, first aid, the disclaimer and
  the acknowledgment gate (rule 4 / D-1), plus the four sections D-7 authorised
  on `EmergencyResultScreen` only.
- **The Health Score is a wellness metric only (D-2)** — it ships as the Care
  Score, computed from record completeness, banded by `careBand()`. **Every
  surface computes it the same way**: `careScore(pet, hasCheck:, hasReminder:)`
  with `hasReminder` read from `remindersForPetProvider`. The baseline screen
  printed 29 against the timeline's 43 until it did.
- **The action ladder's four hues are safety-locked** and never repurposed as
  decoration. Six decorative palettes now each carry a guard test:
  `vaccineTint`, `reminderTint`, `breakdownTints`, `AssistantTone`,
  `HealthTone`, and **`WalkBand`**.
  **The one deliberate exception** is a past AI check chipped in its own ladder
  colour — on the health timeline, and on the pets list (F-4).
- Disclaimers are **API-injected**; the UI only gates on `disclaimerRequired`.
- **The assistant never implies a veterinary role** (V-23), its chips never
  presuppose a symptom (V-12), and it is not a second triage entry point.

### What this batch added to the list

- **Never print a textbook reference range under a pet's name.**
  `know_your_baseline` draws "Resting Heart Rate 60–100 bpm · Your Pet's Normal
  Range". 60–100 bpm and 38.0–39.2 °C are real published ranges; captioning
  them as *this animal's* normal is medical content the app has no standing to
  publish, and a reader who then counts 105 at home draws exactly the
  conclusion PawDoc exists to route to a vet.
- **Never grade a risk beside a named condition.** Both breed references print
  "Hip Dysplasia · Risk: Moderate" with a dot meter. The reader of a breed page
  is usually the owner of that breed.
- **Never prescribe exercise.** "Up to 60 minutes a day is ideal for heart
  health and weight control", "Estimated duration 30–45 min", "Ideal distance
  3–5 km" — all gone. `kWalkDurationDisclaimer` sits where they were.
- **Never brand a lookup table as AI.** `scoreWalkHour` is a pure function; the
  references call its output "AI Walk Suggestion".
- **Never invent a calorie.** A burned-calorie figure needs weight, gait and
  metabolism.
- **Never invent a registry field.** AKC ranking, FCI group, recognition year.
- **Never imply monitoring.** "Alerts Triggered · 0" says the app is watching.
  The baseline screen states outright that it is not.
- **Never hand out an ungated symptom list.** `know_your_baseline`'s "View
  Warning Signs" became **Start a health check** — the Check flow is where the
  emergency override, the quota and the ladder apply.
- **A single reading is not a range.** `MeasureBaseline.hasRange` needs two.
- **A "best hour" band needs its hour.** The walk outlook scored a 34 °C day
  "Ideal" from its 06:00 sample — an invitation to walk at noon. The tile
  prints `90 · 06:00` now.

`test/safety_copy_test.dart` is load-bearing. **Do not weaken it to make a
screen pass** — scope it precisely instead. Each rebuilt screen also carries
its own `group('safety', …)`; keep that pattern.

### The *Soon* convention

A feature the mockup draws and the schema cannot hold keeps its control, in
its place, disabled and labelled *Soon*, and tapping it says what is missing.
Never delete the affordance; never fake the value. Currently marked *Soon*:
recurring reminders, lead-up and missed-reminder nudges, personality traits,
family sharing, microchip / colour / neutered / blood type, expenses, memory
tags, albums, video memories, **a memory's time of day, Family/Public memory
sharing, walk tracking (and everything downstream of it — the log, the weekly
totals, the milestones), heart rate / respiratory rate / temperature /
activity baselines, small pets / birds / reptiles in the breed guide, and the
breed-match quiz**.

### Device-local, and the screen must say so

Six stores now: `pawdoc.dose.*`, `pawdoc.reminder.done.*`,
`pawdoc.memory.fav.*` (all via `LocalTickLog`), **`pawdoc.memory.searches`**
(`RecentSearches`), **`pawdoc.breeds.saved`** (`SavedBreeds`) and
`pawdoc.weight_target.<petId>`. Each exists because the table would be a
migration plus an RLS review plus a deploy, all founder-gated. **A control
whose answer is silently forgotten is worse than no control** — so each screen
states where the answer lives.

---

## 8 · Device validation

```bash
export ANDROID_SERIAL=AYXSUKIVJVPZ7HPZ          # Redmi Note 8, 393x851 logical
cd mobile
# NOTE: do NOT `. ../.env` — line 45 is `GOOGLE_SERVER_CLIENT_ID =` with a
# space before the `=`, so sourcing the file aborts. Pull the two values out.
SUPABASE_URL=$(grep -E '^SUPABASE_URL=' ../.env | cut -d= -f2- | tr -d '"')
SUPABASE_ANON_KEY=$(grep -E '^SUPABASE_ANON_KEY=' ../.env | cut -d= -f2- | tr -d '"')
flutter run -d AYXSUKIVJVPZ7HPZ --debug --pid-file=/tmp/flutter.pid \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
kill -SIGUSR1 $(cat /tmp/flutter.pid)   # hot reload
kill -SIGUSR2 $(cat /tmp/flutter.pid)   # hot restart — REQUIRED after adding a
                                        # field to a const class
adb exec-out screencap -p > shot.png
```

**adb driving tips, learned the hard way.**
- **Launch `flutter run` in one shell invocation**, and do not chain it behind
  a command that can fail — a `&&` chain that aborted on `cat /tmp/flutter.pid`
  silently skipped the relaunch this session.
- **Never `am start` the app while `flutter run` is attached.** It opens a
  second activity in a new task with no engine and renders blank white.
- The screen sleeps and the notification shade steals focus. Run
  `adb shell svc power stayon true` and
  `adb shell settings put system screen_off_timeout 1800000` first.
- `input keyevent 111` (ESC) closes the IME on a page but **dismisses a bottom
  sheet**. Use `keyevent 4` (BACK) — but note BACK also **pops the route** when
  no IME is up, which threw away a screen mid-walk this session.
- **Screenshot between steps rather than chaining taps.**
- Wait for the reload to land: `until [ "$(grep -c Reloaded run.log)" -gt "$N" ]`,
  not a fixed sleep.
- `input text "Two%swords"` — `%s` is the space escape.
- Location for the walk screens:
  `adb shell settings put secure location_mode 3` +
  `adb shell pm grant app.pawdoc android.permission.ACCESS_COARSE_LOCATION`
  (FINE is not declared; granting it throws, harmlessly).

---

## 9 · Blockers and environment notes

- **This branch has no PR yet** — see §0.
- **Anonymous sign-in fails** on the dev Supabase project. Device validation
  goes through `uiqa.aug04@example.com` / `PawDoc!2026qa`.
- **Founder-gated migrations** would retire the device-local stores (§7) and
  add the columns behind every *Soon* field. Walk tracking is the largest
  single unlock: it fills the walk log, the weekly totals and the milestones.
- Record attachments still use the deployed `memories/` R2 scope rather than a
  `records/` one.
- `flutter run` drops its session after long idles — relaunch, do not assume
  hot reload landed.
- CI only runs on `pull_request` and pushes to `main`.
- `new-interface/` is still untracked — owner's call.
- **Test data written to the dev account this session:** two memories titled
  "Two desk shots" (Aug 7 2026, Buddy), from one two-photo batch.
- **Device preferences written this session:** `pawdoc.memory.searches` holds
  `snap`; location permission granted; screen timeout raised to 30 min.

---

## 10 · Next recommended action

1. **Open the PR** for this branch (§0), and get it merged.
2. Then the next batch — recommended: the two pre-auth surfaces (§3.1). They
   are the first thing every new user sees and the only screens left on the old
   design.
3. Whatever it is: open the reference and read it in full before writing
   anything, then survey the target file and the primitives table in §4.
   Almost everything a record-shaped screen needs already exists.
4. Build → `flutter analyze` → `flutter test` → `scripts/verify-disclaimers.sh`
   → hot-reload onto the Redmi → screenshot → compare → fix → commit → next
   screen. One screen at a time.
5. Update `RESUME_GUIDE.md`, `PROJECT_PROGRESS_SUMMARY.md` **and**
   `IMPLEMENTATION_CHANGELOG_UI.md` at the end of the session.

### How to reach this batch's screens on device

| Surface | How |
|---|---|
| `add_memory` | Memories Gallery → the **cloud-upload** button, top right |
| `search_memories` | Memories Gallery → the **magnifier** button on the toolbar row, beside the view toggle |
| `smart_walks` | Home → the **Smart walks** card (tap "Show" first if location is off) |
| `weather_walk_advisor` | Smart Walks → the **calendar** button, top right, or its "Full forecast ›" link |
| `know_your_baseline` | Health tab → the **sliders** button → *Know your baseline* (the menu scrolls) |
| `breed_encyclopedia` | Home → the **Breed Encyclopedia** pill |
| `breed_detail` | any breed card in the guide |

### How to reach the earlier batches

| Surface | How |
|---|---|
| `manage_multiple_pets` | the **Pets** tab |
| `pet_profile` / `edit_pet` / `pet_statistics` | Pets tab → a card → Profile / Edit / Health tab |
| `memories_gallery` / `memory_detail` | Pet Profile → **Files** tab → Open journal → a tile |
| `reminder_detail` | Home → Reminders → any row |
| `health_timeline` and the module menu | the **Health** tab, then the sliders button |
| `weight_tracking` / `medication_tracker` / `vaccination_manager` | that menu |
| `add_health_record` | Health tab → **Add Event** |
| `conversation_history` | Home → AI Assistant → **History** |

### How to reach each result variant on device

The loading run holds a non-emergency result for ~33.5s, so budget ~40s.

| Variant | How |
|---|---|
| CALL_TODAY / monitor | pick "Skin irritation" + "Itching" on the details step |
| WATCH_AND_RECHECK | submit with almost no detail |
| GET_HELP_NOW | free text the **client** keyword router does not match, e.g. "belly hugely swollen and hard, retching with nothing coming up, very weak" |
