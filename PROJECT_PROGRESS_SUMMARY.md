# PROJECT_PROGRESS_SUMMARY

Overall project status. Companion to `RESUME_GUIDE.md` (how to continue) and
`memory/UI_PROGRESS.md` (the UI programme's own record).

**Last updated:** 2026-08-07 · **Branch:** `ui-impl-phase-p-onboarding` ·
**Head:** `24205ea`

---

## 1 · Where the product stands

PawDoc is feature-complete and pre-launch. Engineering reached "GO for a
50-user beta" in June; since then the work has been store-readiness, a device
QA programme, and — currently — rebuilding the interface against the
`new-interface/` reference set.

| Area | Status |
|---|---|
| Flutter app | builds, 556 tests green, analyze clean |
| AI service | deployed to Fly; Tier 2 Gemini → Tier 3 Claude |
| Supabase | 3 migrations + 9 Edge Functions deployed |
| Play | AAB 1.0.0+5 built and signed; internal testing configured |
| iOS | never built or run — hard blocker for an Apple release |
| Legal portal | live on AWS CloudFront, app-integrated |

---

## 2 · Screens rebuilt against the reference set

**27 of 57 mockups implemented.**

| # | Mockup | Status | Commit |
|---|---|---|---|
| 1 | `0001-app-first-screen` | ✅ device-verified | `70b8aa1` |
| 2 | `000` auth gateway | ⚠️ built, not re-walked against its mockup | `70b8aa1` |
| 3 | `002-onboarding` | ✅ | `e26b441` |
| 4 | `003-onboarding` | ✅ | `dc67e5e` |
| 5 | `004-onboarding` | ✅ | `699f503` |
| 6 | `005-onboarding` | ✅ | `699f503` |
| 7 | `006-onboarding` | ✅ | `e61aab5` |
| 8 | `007-onboarding` | ✅ | `e61aab5` |
| 9 | `008-onboarding` | ✅ | `76b9988` |
| 10 | `009-onboarding` | ✅ | `76b9988` |
| 11 | `010-home-page` | ✅ | `3881f38` |
| 12 | `ai_health_check_start` | ✅ | `6eb63e5` |
| 13 | `photo_analysis_upload` | ✅ | `6eb63e5` |
| 14 | `symptom_selection` | ✅ | `6eb63e5` |
| 15 | `ai_analysis_loading` | ✅ | `6eb63e5` `9820028` |
| 16 | `ai_analysis_result_low_risk` | ✅ | `4ff08ef` `0715b3c` |
| 17 | `ai_analysis_result_monitor` | ✅ (same implementation, ladder-parameterised) | `4ff08ef` `0715b3c` |
| 18 | `ai_analysis_result_emergency` | ✅ | `102c6f3` |
| 19 | `ai_assistant_home` | ✅ device-verified | `aae4ebe` `9f47ee1` |
| 20 | `ai_assistant_chat` | ✅ device-verified (same implementation, two surfaces of one route) | `aae4ebe` `9f47ee1` |
| 21 | `ai_message_actions` | ✅ device-verified | `aae4ebe` `9f47ee1` |
| 22 | `conversation_history` | ✅ device-verified | `f6715b6` |
| 23 | `health_timeline` | ✅ device-verified | `1cba0e6` |
| 24 | `add_health_record` | ✅ device-verified | `a8c6846` |
| 25 | `weight_tracking` | ✅ device-verified | `c488dea` |
| 26 | `medication_tracker` | ✅ device-verified | `9af3a54` |
| 27 | `vaccination_manager` | ✅ device-verified | `24205ea` |

### Remaining

**30 mockups, none started.** The two pre-auth surfaces still on old design
(`000` re-walk, the sign-in screen) are the highest-visibility gap — every new
user sees them before anything else. After that, roughly in order of how much
they are used: `pet_profile`, `pet_statistics`, `notifications`,
`account_management`, `emergency_hub` (rule 4 / D-1 constrains it hard),
`first_aid_guide`, `prepare_for_vet_visit`, `pdf_health_report_preview`,
`memories_gallery` + `memory_detail` + `add_memory` + `search_memories`,
`breed_encyclopedia` + `breed_detail`, `smart_walks` + `weather_walk_advisor`,
`community_feed` + `community_post_detail` + `create_post` +
`nearby_pet_owners`, `premium_home` + `subscription_plans` +
`upgrade_benefits` + `usage_limits`, `ai_transparency`, `privacy_security`,
`profile`, `edit_pet`, `manage_multiple_pets`, `reminder_detail`,
`know_your_baseline`.

---

## 3 · Completed this session (2026-08-07)

### The health module — six screens, one skeleton

`conversation_history` `f6715b6` · `health_timeline` `1cba0e6` ·
`add_health_record` `a8c6846` · `weight_tracking` `c488dea` ·
`medication_tracker` `9af3a54` · `vaccination_manager` `24205ea`.

Detail is in `IMPLEMENTATION_CHANGELOG_UI.md`. The headlines:

1. **`health/health_sections.dart`** is the shared skeleton all six are built
   from — twenty presentation blocks. `pets/pet_switcher.dart` is the one
   switcher behind all six header chevrons.
2. **`core/paw_nav_bar.dart`.** Five of the six mockups draw the bottom bar on a
   *pushed* screen, so the bar came out of `root_shell.dart` and learned a
   detached mode: the shell's tab index moved to `rootTabProvider`, and a
   detached bar selects a tab and unwinds rather than stacking a second shell.
   Emergency keeps its slot (C-7 / V-24) — the mockups spend it on Settings.
3. **Nothing on these screens is decoration.** The timeline reopens a stored
   analysis from `full_response`; the weight chart is a CustomPainter over the
   logged points; medication doses are parsed out of the schedule the owner
   typed; vaccination "coming up" is driven by the next-due dates that also set
   reminders. Where the data genuinely does not exist — dose ticks, a weight
   target — it is kept on the device and **the screen says so**, because a
   button whose answer is silently forgotten is worse than no button.
4. **Two new record types.** `lab_result` joins `kHealthEventTypes` (plain
   `text` column, no CHECK — no migration), and the form's default becomes Vet
   Visit as the mockup draws it. Attachments upload through the journal's media
   service, so EXIF/GPS is stripped in an isolate before a presigned PUT.
5. **Three pre-existing bugs surfaced and fixed** — see §4 and the changelog:
   every date picker crashed at the default font size; the weight trend drew
   backwards; the result screen stamped every summary "Generated just now".
6. **Four layout defects the widget tests caught before the device did**, all
   the same shape: two `Flexible` children in one `Row` split the space evenly
   and squeeze a name that had room, while a fixed neighbour overflows the row
   under the em-square test font. Weighted flex shares are the fix.

### Earlier sessions

`ai_assistant_home` / `_chat` / `_message_actions` (`aae4ebe`, `9f47ee1`);
`ai_analysis_result_emergency` under D-7 (`102c6f3`); the low-risk / monitor
result fill-out (`0715b3c`); the analysis loading run (`9820028`); home
(`3881f38`); the AI Health Check flow (`6eb63e5`); onboarding 002–009. Their
detail stays in `IMPLEMENTATION_CHANGELOG_UI.md`.

---

## 4 · Known issues

| Issue | Severity | Notes |
|---|---|---|
| Anonymous sign-in fails on the dev Supabase project | blocks guest QA | founder-side config |
| iOS never built or run | release blocker | Apple submission impossible until done |
| `000` auth gateway not re-walked against its mockup | medium | shield overlaps the dog; social-proof line ellipsises |
| Sign-in screen still on the legacy light theme | medium | jarring against the dark app; not yet in a batch |
| Dose ticks are kept on the device | medium | no `medication_doses` table — a migration + RLS policy + deploy, founder-gated. The tracker says so twice, in the schedule card and in its explainer sheet |
| The weight target range is kept on the device | medium | `pets` has no column for it; same founder-gated migration. The sheet says "Saved on this device" |
| Record attachments use the `memories/` R2 scope | low | a dedicated `records/` scope needs `_shared/upload_key.mjs` + three Edge redeploys (founder-gated). Nothing is written to the `memories` table, so an attachment never appears in the journal gallery |
| A medication schedule is parsed from free text | low | `MedicationSchedule.parse` fails to nothing: an unreadable schedule lists the medicine with its text as written and generates no doses |
| `002`'s hero shows faint plate edges | low | |
| Assistant thumbs-up/down is session-local | low | no assistant-message feedback table; the copy does not claim otherwise |
| Assistant voice input marked *Soon* | low | the mic keeps its place in the composer; no speech backend |
| Assistant "at a glance" Energy/Appetite/Mood/Activity marked *Soon* | low | nothing records them |
| Snackbars are light-on-dark app-wide | low | Material 3 default (`inverseSurface`); visible on the assistant's black surfaces but not introduced by it — a global theme decision, not a screen one |
| Result "Save Report" marked *Soon* | low | PDF export exists for vet prep, not per-result |
| Home hero Energy/Mood/Activity marked *Soon* | low | nothing records them yet |
| `new-interface/` untracked (93 MB) | low | owner's call |
| D-4 asset regeneration (6 gaps), D-5 payment marks | low | owner-gated |

---

## 5 · Safety posture

No contract rule has been relaxed. The assistant trio added four departures,
all of them copy or behaviour with the layout preserved:

- **V-23.** Both assistant mockups subtitle the screen "AI Vet Assistant".
  Shipped: "Your everyday pet-care companion" and "Everyday pet care · not a
  diagnosis". `safety_copy_test` already banned the phrase; the new widget
  test asserts the replacement is what renders.
- **V-12.** The first opener is "Why is Buddy itching?" — a symptom asserted
  before the owner has reported anything. All four openers are care-framed.
- **The assistant is not a second triage entry point.** The "Health &
  Symptoms" topic ships as "Health & Records", and the Emergency tile keeps
  its place, its red and its glyph but opens the offline red screen rather
  than asking a model about an emergency. A symptom belongs in the Check flow,
  where the emergency override, the quota rules and the action ladder apply.
- **Decorative colour may not borrow a ladder hue.** The action sheet is
  eight-coloured by design; the mockup paints Create Reminder in the MONITOR
  amber and Report in the EMERGENCY red, and `design_tokens.dart` forbids
  exactly that reuse. `AssistantTone` holds substitutes and a test pins that
  none of them equals one of the four safety-locked values.

Plus D-2 again: the mockup's "Health Score · 92 · Excellent" ships as the Care
Score, computed from record completeness and banded in words about the record.

 Every departure from a mockup is a copy or
content change with the layout preserved, and each is recorded in the commit
that made it. The running list of mockup claims that cannot ship:

confidence percentages · risk levels · severity grades · differentials with
probabilities · named conditions · asserted causes · all-clear headlines and
checklists · clinical health scores.

**Owner decision D-7 (2026-08-04)** changed one line of this: the emergency
*result* screen may now carry the mockup's risk card, reason list, concern card
and score dial — **rewritten**, never copied ("Care Priority · Immediate",
"Why we're flagging this", "Next step · Immediate Veterinary Assessment",
"Review Status · Needs Immediate Attention"). Scope is `EmergencyResultScreen`
only; `EmergencyHelpScreen`, the offline red button, is untouched. Recorded in
`memory/PAST_DECISIONS.md`.

### The health module (2026-08-07)

Four of these six mockups grade the animal. Every claim was replaced and every
card kept its position, glyph and density — the full table is in
`IMPLEMENTATION_CHANGELOG_UI.md`. The rules the batch leaned on:

- **D-2 again.** `health_timeline`'s "Health Score · 92 · Excellent" is the
  Care Score, record completeness, banded in words about the record.
- **No risk levels.** A past AI check is chipped with the action-ladder value
  in the ladder's own safety-locked hue — the one place on the timeline where
  colour carries meaning, and the meaning the ladder already owns. Everywhere
  else the tints are decorative and clear of all four locked values, pinned by
  a test on each screen.
- **No clinical judgement the owner did not make.** `weight_tracking`'s "Ideal
  Range" is the owner's own target or no band at all; `vaccination_manager`'s
  Core / Non-core / Lifestyle class is owner-selected and never inferred from a
  name.
- **No grade over no data.** Medication adherence is counted from doses
  actually ticked and is **null, not zero**, when nothing was scheduled — 0%
  would read as a failure that never happened. Neither it nor the vaccine
  summary is banded with a value judgement.
- **No dosing or schedule guidance.** The medication tips card and the vaccine
  education card both point at the label and the vet.
- **No second triage entry point.** The record form's sixth type tile ships as
  Weight, not the mockup's "AI Analysis": an AI check belongs to the Check
  flow, where the emergency override, the quota rules and the action ladder
  apply.
- **V-22 provenance.** The record-detail sheet is marked *"Entered by the
  owner. PawDoc did not review it."*

New running list of mockup claims that cannot ship, on top of the earlier one:
ideal-weight bands · immunity/protection status · adherence grades ·
fabricated efficiency metrics ("time saved") · dosing instructions.

`test/safety_copy_test.dart` (regex sweep over `lib/`) and
`test/onboarding_system_a_test.dart` are the tripwires, now joined by a
per-screen safety group in `conversation_history_test`, `health_timeline_test`,
`weight_tracking_test`, `medication_tracker_test` and
`vaccination_manager_test`. `scripts/verify-disclaimers.sh` passes.

---

## 6 · Testing and validation

| Gate | Result |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | **556 passed** |
| `scripts/verify-disclaimers.sh` | PASS |
| `scripts/verify-no-placeholders.sh` | OK on overclaims; founder-fill items remain |
| Device (Redmi Note 8, 393×851) | every screen in §2 walked. This batch was walked with **real data written through the app**: a vet visit, three weights, two medicines with schedules, one dose ticked, a Rabies record with a class and a next-due date |
| CI | runs on PRs and `main` only — this branch has not triggered it |

**Not run** (headless / founder-side): iOS, the release-build matrix, the RLS
Docker suite, `node --test` on Edge Functions.

---

## 7 · Latest commits

```
24205ea  Vaccination Manager rebuilt against its mockup
9af3a54  Medication Tracker rebuilt against its mockup
c488dea  Weight Tracking rebuilt against its mockup — and two shipped bugs it surfaced
a8c6846  Add Health Record rebuilt against its mockup
1cba0e6  Health Timeline rebuilt against its mockup
f6715b6  Conversation history rebuilt against its mockup, and the nav bar it draws
d332978  docs: the assistant trio, and two traps worth writing down
9f47ee1  Assistant: the device pass on the conversation and the action sheet
aae4ebe  Assistant rebuilt against ai_assistant_home / _chat / _message_actions
bfa7583  docs: emergency result (D-7) and the result-screen fill-out
0715b3c  Result screens: fill the gaps the safety rewrite left behind
102c6f3  Emergency result rebuilt against its mockup (owner decision D-7)
4ff08ef  Result screen rebuilt against ai_analysis_result_low_risk / _monitor
9820028  Analysis loading: the run finishes before the result appears
6eb63e5  AI Health Check: the four-screen guided flow
3881f38  Home rebuilt against mockup 010
```

---

## 8 · Next milestones

1. Owner's call on the next batch. Recommended: the two pre-auth surfaces —
   `000` re-walked and the sign-in screen re-skinned off the legacy light
   theme. They are the first thing every new user sees and the only screens
   left on the old design.
2. Open a PR for this branch so CI runs; `main` is protected (linear history +
   review), so it must be squash-merged.
3. `new-interface/` is still untracked (93 MB) — owner's call whether it lands
   in the repo or stays out.
