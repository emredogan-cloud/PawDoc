# RESUME_GUIDE

**Read this first.** It is written so a fresh agent can continue in minutes
without asking questions.

**Last updated:** 2026-08-08 · **Branch:** `ui-batch-t-prep-report-premium`
**Head:** `04fa5aa` · **Gates:** `flutter analyze` clean · **968 tests** green ·
`verify-disclaimers` PASS

---

## 0 · State of the branch

PR #99 **merged** (squash, `b7559b9`). This branch was cut fresh from that
`main`, so there is no stacking.

```
04fa5aa  Device pass on the Redmi: six labels the widget tests could not measure
747f7f1  Tests for the six screens — and three defects they found
f1acc80  Vet-visit prep and the health report preview, rebuilt
afc622d  The four monetization surfaces rebuilt — one catalogue, no invented claims
```

GitHub refuses PR-author self-approval, so a merge needs a human approval or
`gh pr merge --squash --admin`.

**Two CI facts learned the hard way this session.** The workflow pins
`channel: stable` with no version, so CI resolves a *newer* Flutter than the
3.41.9 this repo builds against — it broke on an `onReorder` deprecation with
no code change (silenced with an `ignore`, since the replacement does not
exist locally). And CI runners are **UTC**: two fixtures that pinned dates or
used `now - 2h` were green locally and red at 01:28 UTC. Before pushing, run
`TZ=UTC flutter test` — and if UTC is currently between 00:00 and 02:00, that
is exactly the window that breaks them.

---

## 1 · Current phase

Rebuilding the app's screens against the reference mockups in `new-interface/`
(**58** PNGs, untracked, ~93 MB — earlier batches said 57 and were one short;
`ls new-interface/*.png | wc -l` is the answer). **53 of 58 implemented.**

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
| `breed_encyclopedia` | `encyclopedia/encyclopedia_screen.dart` (rebuilt) | `82d2cf6` |
| `breed_detail` | `encyclopedia/breed_detail_screen.dart` (rebuilt) | `82d2cf6` |
| **`first_aid_guide`** | **`emergency/first_aid_guide_screen.dart`** (new) | **`5331ad9`** |
| **`emergency_hub`** | **`emergency/emergency_help_screen.dart`** (rebuilt) | **`5287501`** |
| **`nearby_pet_owners`** | **`community/nearby_screen.dart`** (new) | **`895c000`** |
| **`community_feed`** | **`community/community_home_screen.dart`** (rebuilt) | **`197ba70`** |
| **`community_post_detail`** | **`community/community_chat_screen.dart`** (rebuilt) | **`197ba70`** |
| **`create_post`** | **`community/create_post_screen.dart`** (new) | **`197ba70`** |
| **`prepare_for_vet_visit`** | **`prep/vet_visit_prep_screen.dart`** (rebuilt) + `prep/vet_visit_prep.dart` | **`f1acc80`** |
| **`pdf_health_report_preview`** | **`health/health_report_preview_screen.dart`** (new) + `health/report_preview.dart` | **`f1acc80`** |
| **`premium_home`** | **`monetization/premium_home_screen.dart`** (new) | **`afc622d`** |
| **`subscription_plans`** | **`monetization/paywall_screen.dart`** (rebuilt) | **`afc622d`** |
| **`upgrade_benefits`** | **`monetization/upgrade_benefits_screen.dart`** (new) | **`afc622d`** |
| **`usage_limits`** | **`monetization/usage_limits_screen.dart`** (new) | **`afc622d`** |

All device-walked on the Redmi Note 8 (`AYXSUKIVJVPZ7HPZ`, 1080×2340 @440dpi =
**393×851 logical** — the same size the mockups are drawn at).

---

## 3 · Remaining work — 5 mockups

### 3.1 · The two pre-auth surfaces (still the highest-visibility gap)

`000` (the auth gateway) was built but never re-walked against its mockup —
the shield overlaps the dog and the social-proof line ellipsises. The sign-in
screen is still on the legacy **light** theme. Both are the first thing every
new user sees and the only screens left on the old design.

### 3.2 · The rest of the set

`notifications`, `account_management`, `profile`, `ai_transparency`,
`privacy_security` — five, and they are one coherent batch: the settings
surfaces. All already have shipping screens; the work is a rebuild against the
reference. Check `lib/src/{account,notifications,config}/` first.

`account_management`, `profile` and `privacy_security` all overlap
`account_screen.dart`, so read all three references before touching it. The
Premium row inside it now opens `PremiumHomeScreen` (the hub), not the
paywall — keep that.

---

## 4 · Reusable primitives — extend these, do not duplicate

`health/health_sections.dart` is the shared skeleton **eighteen** screens are
built from. It grew again this batch.

| Primitive | Added | Use |
|---|---|---|
| **`HealthStepRail`** | batch R | the numbered wizard rail. 26dp circles on the reference's own centres (23dp inset, four equal columns → 66/153/240/327 on a 393 screen). The whole column is the tap target, not the dot |
| **`HealthNumberedHead`** | batch R | "**1.** Add Photos" + subtitle + `(Optional)` suffix |
| **`HealthCountedField`** | batch R | a bordered box with a live `0/60` counter; single-line puts it inline, multiline beneath |
| **`HealthDashedTile`** + **`HealthDashedPainter`** | batch R | the dashed well. **Collapsed two private painters** that had already been written twice |
| **`HealthDropPill`** | batch R | the "All Types ⌄" lozenge. Replaced `memories_screen`'s private `_DropButton` |
| `HealthPrimaryCta` (+ `icon` honoured, `trailingIcon`, `enabled`) | fixed in batch R | it accepted an `icon` and drew a hardcoded `plus` — the journal's "See Premium" rendered its crown as a **+** |
| `HealthSearchField` (+ `onSubmitted`, + **`focusNode`**) | `focusNode` this batch | so a screen can decide what to *remember*, and so the first-aid guide's hero button can hand focus to the field |
| `HealthActionPill`, `HealthInfoGrid`/`HealthInfoCell`, `HealthSettingRow`, `HealthSparkline`, the six-widget form kit, `HealthStat`, `HealthStatTiles`, `HealthRecordRow`, `HealthGlyphDisc`, `HealthPill`, `HealthMetaBlock`, `HealthStatusBadge`, `HealthAddCard`, `HealthEduCard`, `HealthPrivacyCard`, `HealthDangerCard`, `HealthSheet`, `HealthDetailRow`, `HealthRecordScaffold` + `HealthBleed`, `HealthFilterChips`, `HealthRingPortrait`, `PetModuleAppBar`, `PetModuleHeaderCard`, `HealthTone`, `kRecordGutter` | — | the rest of the skeleton |

New modules this batch:

| File | Holds |
|---|---|
| **`monetization/entitlements.dart`** | `kEntitlements` — **the audited catalogue every premium surface renders**, plus `kFreePhotoChecksPerMonth`/`kFreeAssistantMessagesPerDay`/`kFreeJournalEntries`, `EntitlementKind`, `premiumUnlocks`, `includedForEveryone`, `entitlementById`, `UsageMeter`, `buildUsageMeters`. **A screen asks this file what a capability is worth and cannot invent one.** `entitlements_test` reads the enforcing `.mjs` files and fails on drift |
| **`monetization/premium_sections.dart`** | `PremiumTone` (guarded), `PremiumCrest`, `PremiumChip`, `entitlementChip`, `PremiumHeroCard`, `PremiumFeatureStrip`, `PremiumFeatureCard`/`Grid`, `EntitlementCompareTable`, `UsageMeterRow`, `PremiumBand`, `PremiumFaq`, `PremiumHonestyNote` |
| **`monetization/usage_state.dart`** | `AccountUsage`, `accountUsageProvider`, `assistantMessagesTodayProvider` (same UTC window `assistant-chat` counts) |
| **`monetization/subscription_state.dart`** | `SubscriptionSnapshot`, `subscriptionSnapshotProvider`, `planLabelFor`. Guarded on `Env.hasRevenueCat`, bounded by `kEntitlementProbeTimeout` |
| **`prep/vet_visit_prep.dart`** | `VisitPrepDraft` (device-local, per pet), `kVisitReasons`, `SymptomFrequency`, `SymptomChange`, `kBringItems`, `kQuestionExamples`, `PrepStep`, `completedPrepSteps`, `visitPrepAnswerLines` |
| **`health/report_preview.dart`** | `ReportPreview`/`ReportSection`, `buildReportPreview`, `paginateReport`, `kPdfReportDisclaimer`, `kPdf*Heading`, `kPdfReportWindow`, `kPdfMaxRows`, `kReportIncludes`/`kReportExcludes`. **A Dart mirror of `_shared/pdf_report.mjs`**, pinned by `pdf_report_preview_test` |
| **`emergency/emergency_sections.dart`** | `kPoisonControlLabel`/`Number`/`Note`, `dialPoisonControl`, `openEmergencyVetMaps`, `kFirstAidOrder`, `orderedFirstAidTopics`, `searchFirstAid`, `firstAidGlyph`/`RailIcon`/`ShortLabel`, `FirstAidGlyph`, `EmergencyCallBand`, `EmergencyHonestyNote`, `FirstAidRow`, `FirstAidCategoryRail`. **Bound by the emergency-path rule** — nothing here may reach a model, a paywall or the network beyond the two OS hand-offs |
| **`community/community_sections.dart`** | `communityInitials`, `SpeciesFilter`, `PeopleOrder`, `searchProfiles`, `filterPeople`, `speciesTally`, `kCommunityGuidelines`, `kCommunityPrivacyLine`, `CommunityAvatar`, `CommunityActionButton`, `CommunityTallyStrip`, `CommunityGuidelinesCard`, `CommunitySoonChip` |
| **`test/support/fake_community.dart`** | `FakeCommunityRepo`, `FakeLocation`, `communityApp()`, `communitySurface()` — the harness all four community suites share. `community_screens_test` used to carry its own copy |
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
15. **`Spacer()` is an `Expanded`.** A Row ending in `Spacer` and containing
    a `Flexible` splits the free space between them, so the flexible child
    ellipsises with slack sitting idle beside it. Put the leading group in one
    `Expanded` and the trailing control after it. (`HealthNumberedHead`, found
    on device this batch — rule 9 in a second disguise.)
16. **`hasError` is checked before `isLoading`.** Riverpod 3 retries a failed
    provider, which flips it straight back to `loading` and makes
    `when(error:)` unreachable. `home_screen` already did this; `usage_limits`
    had to learn it. In tests, override with `Future.error(...)` rather than
    `async { throw }` for the same reason.
17. **An unconfigured store SDK never answers.** `Purchases.getOfferings()`
    and `getCustomerInfo()` do not reject when `Purchases.configure` was never
    called — they hang. Guard on `Env.hasRevenueCat` **and** bound with
    `kEntitlementProbeTimeout`. Three call sites have now been caught by this.
18. **A widget test cannot pump past a `CircularProgressIndicator`** — it
    never settles, so the state it guards is untestable. The project's motion
    foundation wants a static reduce-motion equivalent anyway.
19. **The repo is hand-formatted at 80 columns and is NOT `dart format`-clean.**
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

### What the community and emergency batch added to the list

- **The red path reads no app state, and a test proves it.**
  `EmergencyHelpScreen` and `FirstAidGuideScreen` both render with **no
  `ProviderScope`**; `emergency_hub_test` and `first_aid_guide_test` pump them
  bare. That is why neither adopts the mockup's bottom navigation —
  `PawNavBar` is a `ConsumerWidget`, and a tab bar is not worth trading the
  proof for. If a future change needs a provider on those screens, the tests
  fail rather than the cold offline start.
- **Never badge some rows urgent.** The reference marks four of seven
  first-aid topics "High Priority", which tells the reader the other three are
  not. Order carries urgency (`kFirstAidOrder`, review item V-27) and the
  section head says so.
- **Never print a read time on an emergency surface.** "🕐 6 min" is invented,
  and to an owner holding a bleeding animal it reads as a cost. Rows print the
  card's step count.
- **Never advertise a service PawDoc does not run.** "Call Emergency ·
  Available 24/7" implies a staffed line; the 24/7 clinic directory with star
  ratings implies a data source that was deleted in PR #80. What is real: the
  maps hand-off, and somebody else's poison-control number with its fee stated.
- **Never verify a person.** The community reference badges a "Vet Dr." with a
  blue check answering a health question in-feed, and a "Top Contributor". A
  badge that implies PawDoc vouches for a stranger's advice is the most
  consequential invention in the whole reference set. `community_trio_test`
  scans every rendered string on the feed and the detail screen for it.
- **Never plot a member.** Discovery stores a five-character geohash *cell*
  (~4.9 km) and no coordinates. The reference's map pins people at 0.2–0.6
  miles from a "You" marker; a map that resolves to a tenth of a mile is a map
  to a door. A test asserts no decimal distance can reach the screen.
- **Never imply presence.** "Active now" is not stored, and would be
  location-adjacent if it were.
- **Never let a failed lookup read as an empty world.** `snapshot.data ?? []`
  turned a network error into *"Nobody discoverable in your area yet — you are
  early"*. Both community list screens now distinguish the two.

### What the vet-prep, report and premium batch added

- **Never sell a veterinarian.** The reference's *"Vet Chat Priority — get
  faster responses from verified veterinarians"* is the single most
  consequential invention in the whole set: it sells a licensed opinion, in a
  health app, to an owner with a sick animal. Nor *"premium tools made by
  vets"* — nobody clinical authored this product.
- **Never quote a price the store did not return.** Every figure comes from
  `storeProduct.priceString`; "Save N%" is `PaywallPricing.savingsBadge` over
  two live prices in one currency, hidden when it cannot be computed.
- **Never promise a trial or a refund.** A trial exists only when
  `storeProduct.introductoryPrice != null`. Refunds are Google's; PawDoc runs
  no money-back guarantee and says so.
- **Never invent social proof.** No ratings, review counts, customer counts or
  "loved by pet parents". Pre-launch, there are none — the same defect as the
  onboarding "★ 4.8" line.
- **Never draw a bar without a measurement.** The reference meters storage,
  vet chat, pets and analytics — four things nothing counts. A meter is either
  counted or declares it is not. A failed count says *"could not be read"*,
  never `0`.
- **Never sell what is already free.** Pets, records, reminders, the text
  export, community and the vet prep pack are unlimited on both plans, and the
  comparison table says so on both sides.
- **Never put a severity meter beside a symptom.** `prepare_for_vet_visit`
  draws signal bars reading "Moderate". Replaced by a trajectory (better /
  worse / same / comes and goes), which is the question a vet asks.
- **Never carry the owner into the export.** The PDF contains the animal, not
  the person — no name, phone, email or city. The preview *states* the
  omission rather than being quietly better than the reference.
- **Never let planning crowd out the red path.** The prep screen carries a
  calm, permanent Emergency strip that reads nothing back and is identical for
  everyone, because sitting down to plan is exactly the posture that defers an
  emergency to Tuesday.
- **The payment marks stay out** (decision D-5, none sourced); a sentence
  naming Google Play carries the same reassurance and is verifiable.

### What the memories, walks, baseline and breeds batch added

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

Seven stores now: **`pawdoc.visit_prep.<petId>`** (`VisitPrepDraft`),
`pawdoc.dose.*`, `pawdoc.reminder.done.*`,
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

- **This branch has no PR yet at the time of writing** — see §0.
- **`community_post_detail` was not device-walked with a live second member.**
  The dev project has no other community profile within reach of the QA
  account's cell, and creating one is a data action on a shared project rather
  than a UI change. The screen is covered by ten widget tests, three of which
  drive send, report and proposal-accept through the repository.
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
- **Test data written to the dev account this session (2026-08-08):** a
  `community_profiles` row for the QA account — display name `QAWalker`, bio
  `Morning walks`, species `dog`, area code `sy96x`, discoverable, accepting
  requests. It was created through the consent gate to reach the community
  screens. **Deleting it is one tap in-app** (Community → ⋮ → Leave the
  community, which cascades the profile and any graph), but it is the owner's
  call whether to.
- **Device preferences written earlier:** `pawdoc.memory.searches` holds
  `snap`; location permission granted; screen timeout raised to 30 min. The
  font scale was set to 1.3 for an accessibility pass and **restored to 1.0**.

---

## 10 · Next recommended action

1. **Open the PR** for this branch (§0), and get it merged.
2. Then the next batch — recommended: the two pre-auth surfaces (§3.1). They
   are the first thing every new user sees and the only screens left on the old
   design. `CommunityOnboardingScreen` is a third screen still on the legacy
   design, and it is the community's **consent gate**, so it is worth the same
   pass — but its content is load-bearing, not decorative. After that, the
   five remaining references (§3.2) are one coherent settings batch.
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
| `prepare_for_vet_visit` | Home → the **Prepare for a vet visit** pill, or Health → the sliders button → *Vet visit prep* |
| `pdf_health_report_preview` | Health → the sliders button → **Health report** |
| `premium_home` | Home → the **person** icon (top right) → **PawDoc Premium** |
| `subscription_plans` | Premium hub → **See plans** (hero, plan card, or the closing band); also every existing upsell |
| `upgrade_benefits` | Premium hub → **Compare plans** or the **?** action; Subscription Plans → the **?** action |
| `usage_limits` | Premium hub → **Your usage**; Upgrade Benefits → **Your usage** |

### The previous batch's screens

| Surface | How |
|---|---|
| `emergency_hub` | the **Emergency** destination in the bottom nav, or Home's red button |
| `first_aid_guide` | Emergency Hub → the **Pet First Aid** tile, or the **Search** pill beside "First aid while you get help" |
| a first-aid card | either screen's topic rows |
| `community_feed` | Home → the **Paw Community** card (join first if the card reads "Opt-in only") |
| `nearby_pet_owners` | Community → the **magnifier** in the header, or "Nearby pet people → **See all**" |
| `create_post` | Community → **Edit profile**, the composer card, the ⋮ menu, or the round FAB |
| `community_post_detail` | Community → any **accepted connection** card. Needs a second member |

### The earlier batch's screens

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
