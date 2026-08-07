# RESUME_GUIDE

**Read this first.** It is written so a fresh agent can continue in minutes
without asking questions.

**Last updated:** 2026-08-07 · **Branch:** `ui-impl-phase-p-onboarding`
**Head:** `24205ea` · **Gates:** `flutter analyze` clean · 556 tests green ·
`verify-disclaimers` PASS

---

## 1 · Current phase

Rebuilding the app's screens against the reference mockups in `new-interface/`
(57 PNGs, untracked, ~93 MB). Onboarding, home, the AI Health Check flow, all
three result screens, the assistant trio **and the six-screen health module**
are finished. **27 of 57 mockups implemented.**

Working method, unchanged and expected to continue:

> read the reference → implement at full fidelity → `flutter analyze` →
> `flutter test` → hot-reload onto the Redmi → screenshot → compare →
> fix → commit → next screen.

One screen at a time, each through the full gate set before the next.

---

## 2 · Completed screens

| Mockup | Implementation | Commit |
|---|---|---|
| `0001-app-first-screen` | `onboarding/first_run_screen.dart` | `70b8aa1` |
| `000` auth gateway | `onboarding/auth_gateway_screen.dart` | `70b8aa1` |
| `002`–`009` onboarding | `onboarding/onboarding_flow.dart` + `onboarding_stages.dart` + `onboarding_ui.dart` | `e26b441` `dc67e5e` `699f503` `e61aab5` `76b9988` `295fff5` |
| `010-home-page` | `home/home_screen.dart` + `home/home_sections.dart` | `3881f38` |
| `ai_health_check_start` / `photo_analysis_upload` / `symptom_selection` / `ai_analysis_loading` | `health_check/` | `6eb63e5` `9820028` |
| `ai_analysis_result_low_risk` + `_monitor` | `analysis/result_screen.dart` + `health_check/result_sections.dart` | `4ff08ef` `0715b3c` |
| `ai_analysis_result_emergency` | `analysis/emergency_result_screen.dart` | `102c6f3` |
| `ai_assistant_home` + `_chat` + `ai_message_actions` | `assistant/assistant_screen.dart` + `assistant_sections.dart` | `aae4ebe` `9f47ee1` |
| `conversation_history` | `assistant/conversation_history_screen.dart` | `f6715b6` |
| `health_timeline` | `health/history_timeline_screen.dart` | `1cba0e6` |
| `add_health_record` | `health/health_event_form_screen.dart` | `a8c6846` |
| `weight_tracking` | `health/weight_tracking_screen.dart` | `c488dea` |
| `medication_tracker` | `health/medication_tracker_screen.dart` | `9af3a54` |
| `vaccination_manager` | `health/vaccination_manager_screen.dart` | `24205ea` |

All device-walked on the Redmi Note 8 (`AYXSUKIVJVPZ7HPZ`, 1080×2340 @440dpi =
**393×851 logical** — the same size the mockups are drawn at).

---

## 3 · Remaining work — start here

**30 mockups remain, none started.**

### 3.1 · The two pre-auth surfaces (recommended next)

`000` (the auth gateway) was built but never re-walked against its mockup —
the shield overlaps the dog and the social-proof line ellipsises. The sign-in
screen is still on the legacy **light** theme, which is jarring against the
rest of the app. Both are visible to every new user before anything else, and
they are the only screens left on the old design.

### 3.2 · The rest of the set

`pet_profile`, `pet_statistics`, `notifications`, `account_management`,
`emergency_hub` (rule 4 / D-1 constrains it hard — read §7 first),
`first_aid_guide`, `prepare_for_vet_visit`, `pdf_health_report_preview`,
`memories_gallery` + `memory_detail` + `add_memory` + `search_memories`,
`breed_encyclopedia` + `breed_detail`, `smart_walks` + `weather_walk_advisor`,
`community_feed` + `community_post_detail` + `create_post` +
`nearby_pet_owners`, `premium_home` + `subscription_plans` +
`upgrade_benefits` + `usage_limits`, `ai_transparency`, `privacy_security`,
`profile`, `edit_pet`, `manage_multiple_pets`, `reminder_detail`,
`know_your_baseline`.

Most of these already have shipping screens; the work is a rebuild against the
reference, not a new feature. Check `lib/src/{memories,encyclopedia,walks,
community,monetization,account,notifications,prep,emergency}/` first.

---

## 4 · Reusable primitives — extend these, do not duplicate

| Primitive | File | Use |
|---|---|---|
| `PetModuleAppBar`, `PetModuleHeaderCard`, `HealthRingPortrait`, `HealthAsidePill`, `HealthCircleButton`, `HealthSectionHead`, `HealthGroupLabel`, `HealthFilterChips`, `HealthStatTiles` (+`HealthStat`, `HealthStatLayout`), `HealthRecordRow`, `HealthGlyphDisc`, `HealthPill`, `HealthMetaBlock`, `HealthStatusBadge`, `HealthAddCard`, `HealthEduCard`, `HealthPrivacyCard`, `HealthDangerCard`, `HealthPrimaryCta`, `HealthSheet`, `HealthDetailRow`, `HealthRecordScaffold` + `HealthBleed`, `HealthTone`, `kRecordGutter` | `health/health_sections.dart` | **the skeleton every record surface is built from** — six screens already, and the obvious base for `pet_profile`, `pet_statistics`, `notifications` and the memories/encyclopedia lists |
| `showPetSwitcher(context, ref)` | `pets/pet_switcher.dart` | the one switcher behind every header chevron |
| `PawNavBar(detached:)`, `rootTabProvider`, `openQuickActionSheet` | `core/paw_nav_bar.dart` | the bottom bar, on the shell **and** on pushed screens |
| `showHealthRecordDetail(...)` | `health/health_record_detail.dart` | what any record row's "View details" opens |
| `MedicationSchedule`, `Medication`, `DoseSlot`, `DoseLog`, `doseLogProvider`, `Adherence` | `health/medication_plan.dart` | the medication model + the free-text schedule parser |
| `WeightTarget`, `weightTargetProvider` | `health/weight_target.dart` | the owner's own weight range |
| `WeightPoint`, `weightPointsProvider` | `health/weight_trend_card.dart` | weight points, oldest→newest |
| `TimelineItem`, `healthTimelineProvider` | `health/timeline.dart` | analyses + health events, merged, newest first |
| `HomeCard`, `HomeCardHeader`, `HomeListCard`, `HomeQuickActions`, `HomeStatStrip`, `PetRail`, `PetPortrait`, `HomeBrandBar`, `HomeGreeting`, `PetHeroPanel`, `careScore`, `petAgeLabel` | `home/home_sections.dart` | every dark slab in System B, app-wide |
| `HealthCheckAppBar`, `HealthCheckSteps`, `HealthCheckDisclaimer`, `HealthCheckScaffold` (all take a `tint`) | `health_check/health_check_chrome.dart` | the check flow |
| `ResultHero`, `ResultActionCard`, `ResultSummaryCard`, `ResultListCard`, `ResultActionRow`, `ResultActionBar`, `ResultTrendCard`, `ResultAssistantStrip`, `ResultStatusCard`, `ResultGuideStrip`, `ResultReminderRow` | `health_check/result_sections.dart` | all three result screens |
| `AssistantAppBar`, `AssistantHero`, `AssistantComposer`, `AssistantUserBubble`, `AssistantReplyBubble`, `AssistantActionSheet`, `AssistantTone`, … (19 blocks) | `assistant/assistant_sections.dart` | the assistant trio; the bubbles, composer and action sheet are reusable anywhere a conversation appears |
| `OnbPage`, `OnbNeonCard`, `OnbCrest`, `OnbPhoneMockup`, … | `onboarding/onboarding_ui.dart` | System A (onboarding) only |
| `PawCard`, `PawPanel`, `PawPillButton`, `PawPrimaryButton`, `PawBackground`, `PawTone`, `BlendMask` | `theme/paw_components.dart`, `theme/paw_ui.dart` | app-wide |

**Dependency direction:** `assistant → health → home → theme`. Never the other
way. `health_sections.dart` deliberately imports neither `assistant_sections`
nor anything above it, which is why `HealthTone` restates the grey ramp instead
of importing `AssistantTone`.

---

## 5 · Architecture decisions in force

1. **Two visual systems.** System A = onboarding (navy / emerald / cyan).
   System B = the product (near-black / lime). Declared at the app root;
   onboarding overrides to A. `system_isolation_test.dart` pins the boundary.
2. **The mockups are AI-rendered pictures, not exported frames.** Their body
   copy measures ~8-12dp and statistic labels ~7.5dp — unreadable on a handset.
   Match layout, spacing and composition exactly; set type ~15% above the naive
   scale. Page gutter is 17–18dp (measured), not 20. A label that no longer
   fits at readable type gets a fixed two-line slot or `FittedBox`, never an
   ellipsis mid-word.
3. **Pinned footers.** Onboarding uses `OnbPage`; the check flow uses
   `HealthCheckScaffold`; the record screens use `HealthRecordScaffold`. All
   scroll content under an opaque action plate so the CTA is reachable on the
   first frame.
4. **`HealthRecordScaffold` applies the gutter per child**, so a `HealthBleed`
   child can paint edge to edge. Negative padding is not a thing in Flutter.
5. **The bottom nav lives in `core/paw_nav_bar.dart`, not in the shell.** Five
   record mockups draw it on a *pushed* screen. `PawNavBar(detached: true)`
   selects the tab via `rootTabProvider` and unwinds to the shell. A screen
   that is *also* a shell tab (only `HealthHistoryScreen`) takes an `embedded`
   flag so it does not stack a second bar — **including on its no-pet branch**,
   which is where `root_shell_test` caught it.
6. **`PendingPet`** holds the onboarding pet until there is a session; flushed
   in `RootShell.initState`.
7. **The analysis wait is deliberate** (~33.5s). See §6.
8. **Bodies are a Column in a scroll view**, not a lazy ListView — laziness
   hid content from tests and screen readers alike. The *conversation* is the
   exception: a `reverse: true` `ListView.builder`, because a thread is
   genuinely long.
9. **Widget tests must set a handset surface.** The default test window is
   800×600 — wider and far shorter than any phone — so on a tall scrolling
   screen everything below the fold is never built and the assertions pass
   vacuously. Every screen test here sets 393×(1600–2600).
10. **In `flutter_test` every glyph is a full em square.** A `Row` that fits
    comfortably on device overflows in a test. That is a feature: it has now
    found seven real defects before the device did. Make the label `Flexible` +
    `FittedBox`; do not widen the box to silence it.
11. **Two `Flexible` children in one `Row` split the free space evenly**, which
    squeezes a name that had room; a fixed neighbour overflows the row under
    the test font. Use **weighted shares** (3:2, 5:4). This bit three times in
    one batch.
12. **Inside an `IntrinsicHeight`, a `Text` reports its unwrapped single-line
    height**, so a label wanting two lines is clipped to one and the second is
    silently lost. Give it an explicit `SizedBox` slot.

---

## 6 · The analysis loading run — how it works

`health_check/health_check_loading_view.dart`

- A `TweenSequence` over `HealthCheckLoadingView.ceremony` (33.5s): fast off
  the mark, slow through the model stage, short close.
- Six stages tick against the **percentage**, not a clock.
- If the backend runs long the bar parks at 99 (`_hold = 0.985`) and says
  "Finishing up…"; the answer closes out the last point and hands over.
- **Never held:** an EMERGENCY (instant cut) and reduce-motion. Errors are not
  held either.
- `health_check_ceremony_test.dart` pins all four cases.

**Trap:** `flutter_test_config.dart` sets `disableAnimations` on the *binding*,
and `AnimationController` scales every duration by **0.05** when that is set —
independent of any MediaQuery override. A 33.5s run finishes in ~1.7s of test
time.

---

## 7 · Safety rules that constrain every screen

Read `CLAUDE.md` in full. The ones that bite in UI work:

- **Confidence is never rendered.** Ever. `safety_copy_test.dart` greps for it.
- **No differential, no percentages, no risk level, no severity grade.**
- **Never name a condition** and never assert a cause.
- **No output terminates without an action and a timeframe**; never render
  "normal" or any all-clear.
- **The emergency surfaces** carry help contacts, first aid, the disclaimer and
  the acknowledgment gate (rule 4 / D-1) — **plus**, since owner decision
  **D-7**, the four sections `ai_analysis_result_emergency` adds, rewritten in
  PawDoc language. D-7's scope is `EmergencyResultScreen` only;
  `EmergencyHelpScreen` (the offline red button) stays model-free.
- **`EmergencyResultScreen` renders zero motion widgets, permanently.**
- **The Health Score is a wellness metric only** (D-2) — it ships as "Care
  Score", computed from record completeness.
- **The action ladder's four hues are safety-locked** and never repurposed as
  decoration. The one deliberate exception is a *past AI check* on the health
  timeline, which is chipped in its own ladder colour because that is the
  meaning the ladder already owns. Every other tint on the record screens is
  decorative and clear of all four values, pinned by a test per screen.
- Disclaimers are **API-injected** — the UI only gates on `disclaimerRequired`.
- **The assistant never implies a veterinary role** (V-23), its chips never
  presuppose a symptom (V-12), and it is not a second triage entry point.

### What the health module added (2026-08-07)

- **Never grade an animal the app has not examined.** No ideal-weight band, no
  protection status, no "fully protected", no "up to date".
- **A clinical judgement the app cannot make is the owner's to enter.** The
  weight target range and the vaccine class are theirs, labelled as theirs, and
  absent until they set them.
- **A metric over no data is null, not zero.** Medication adherence with
  nothing scheduled reads "No doses scheduled", because 0% is a failure that
  never happened.
- **No value judgements.** No "Excellent", no "Great job" — not on the animal
  and not on the owner's week.
- **No dosing or schedule guidance.** Point at the label and the vet.
- **A control whose answer is not stored must say where it goes.** Dose ticks
  and the weight target are device-local and both screens say so.
- **V-22 provenance** on anything the owner typed: *"Entered by the owner.
  PawDoc did not review it."*

`test/safety_copy_test.dart` is load-bearing. **Do not weaken it to make a
screen pass** — scope it precisely instead. Each record screen also carries its
own `group('safety', …)`; keep that pattern.

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
kill -SIGUSR2 $(cat /tmp/flutter.pid)   # hot restart
adb exec-out screencap -p > shot.png
```

A second Redmi (`jfzxugsgnnvsrsg6`, 1080×2408) is also attached — pin
`ANDROID_SERIAL` or adb errors with "more than one device".

**adb driving tips learned the hard way.** `input keyevent 111` (ESC) closes
the IME on a page but *dismisses a bottom sheet*; `keyevent 4` (BACK) closes
the IME on the first press and **pops the route** on the second, which silently
threw away two half-filled forms. Screenshot between steps rather than
chaining taps: the page scroll position shifts as fields fill, and a blind tap
lands in the wrong field. Wait for the reload to land before screenshotting —
`until [ "$(grep -c Reloaded run.log)" -gt "$N" ]`, not a fixed sleep.

---

## 9 · Blockers and environment notes

- **Anonymous sign-in fails** on the dev Supabase project ("Could not start a
  guest session"). Device validation goes through an email account:
  `uiqa.aug04@example.com` / `PawDoc!2026qa`.
- **Three things are device-local, pending founder-gated migrations:** dose
  ticks (`pawdoc.dose.*`), the weight target (`pawdoc.weight_target.*`) and —
  the odd one out — record attachments, which use the deployed `memories/` R2
  scope rather than a `records/` one, because a new scope means editing
  `supabase/functions/_shared/upload_key.mjs` and redeploying
  `generate-upload-url`, `sign-media-url` and `delete-media`.
- `flutter run` drops its session after long idles — relaunch, do not assume
  hot reload landed.
- CI only runs on `pull_request` and pushes to `main`; a branch push alone does
  not trigger it.
- `new-interface/` is still untracked — owner's call.

---

## 10 · Next recommended action

1. **Open a PR for this branch so CI runs.** Six screens and 91 new tests have
   never been through it. `main` is protected (linear history + review), so it
   must be squash-merged.
2. Then the next batch — recommended: the two pre-auth surfaces (§3.1).
3. Whatever it is: open the reference and read it in full before writing
   anything, then survey the target file and the primitives table in §4. Almost
   everything a record-shaped screen needs already exists in
   `health/health_sections.dart`.
4. Build → `flutter analyze` → `flutter test` → `scripts/verify-disclaimers.sh`
   → hot-reload onto the Redmi → screenshot → compare → fix → commit → next
   screen. One screen at a time.
5. Update `RESUME_GUIDE.md`, `PROJECT_PROGRESS_SUMMARY.md` **and**
   `IMPLEMENTATION_CHANGELOG_UI.md` at the end of the session.

### How to reach the health module on device

| Surface | How |
|---|---|
| `health_timeline` | the **Health** tab |
| the module menu | Health tab → the sliders button, top right |
| `weight_tracking` | that menu → Weight tracking, or any Weight row's "View Trend" |
| `medication_tracker` | that menu → Medication tracker, or any Medication row |
| `vaccination_manager` | that menu → Vaccination manager, or any Vaccination row |
| `add_health_record` | Health tab → **Add Event**, or any module's Add CTA (which preselects the type) |
| the record-detail sheet | any Vet Visit / Lab Result / Note row, or a row inside a module |
| `conversation_history` | Home → AI Assistant → the **History** button, top right |

### How to reach each result variant on device

The loading run holds a non-emergency result for ~33.5s, so budget ~40s.

| Variant | How |
|---|---|
| CALL_TODAY / monitor | pick "Skin irritation" + "Itching" on the details step |
| WATCH_AND_RECHECK | submit with almost no detail |
| GET_HELP_NOW | a note like "belly hugely swollen and hard, retching with nothing coming up, very weak" — and note the **client** keyword router intercepts the hardcoded list first and lands on `EmergencyHelpScreen`, so use free text the router does not match |

Past results are now reopenable: Health tab → any AI Health Check card →
**View Result**.
