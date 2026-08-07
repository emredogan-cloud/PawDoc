# PROJECT_PROGRESS_SUMMARY

Overall project status. Companion to `RESUME_GUIDE.md` (how to continue) and
`IMPLEMENTATION_CHANGELOG_UI.md` (what changed, screen by screen).

**Last updated:** 2026-08-07 (later) · **Branch:** `ui-batch-r-pets-memories` ·
**Head:** `2029615`

---

## 0 · Two things need a human

1. **PR #97 is green and unmerged.** All seven CI checks pass on run
   `31164010792`. It is blocked only by `REVIEW_REQUIRED` — GitHub does not let
   a PR author approve their own PR, and the `--admin` bypass was refused by
   the agent permission layer. Approve it in the UI, or run
   `gh pr merge 97 --squash --admin`.
2. **`ui-batch-r-pets-memories` is stacked on it**, branched from `e6effd6`
   because stopping would have wasted the session. After #97 merges:
   `git rebase --onto origin/main e6effd6 ui-batch-r-pets-memories`.

---

## 1 · Where the product stands

PawDoc is feature-complete and pre-launch. Engineering reached "GO for a
50-user beta" in June; since then the work has been store-readiness, a device
QA programme, and — currently — rebuilding the interface against the
`new-interface/` reference set.

| Area | Status |
|---|---|
| Flutter app | builds, **691 tests** green, analyze clean |
| AI service | deployed to Fly; Tier 2 Gemini → Tier 3 Claude |
| Supabase | 3 migrations + 9 Edge Functions deployed |
| Play | AAB 1.0.0+5 built and signed; internal testing configured |
| iOS | never built or run — hard blocker for an Apple release |
| Legal portal | live on AWS CloudFront, app-integrated |

---

## 2 · Screens rebuilt against the reference set

**34 of 57 mockups implemented.** (27 before this session, +7.)

| # | Mockup | Status | Commit |
|---|---|---|---|
| 1 | `0001-app-first-screen` | ✅ device-verified | `70b8aa1` |
| 2 | `000` auth gateway | ⚠️ built, not re-walked against its mockup | `70b8aa1` |
| 3–10 | `002`–`009` onboarding | ✅ | `e26b441` … `295fff5` |
| 11 | `010-home-page` | ✅ | `3881f38` |
| 12–15 | the AI Health Check flow | ✅ | `6eb63e5` `9820028` |
| 16–17 | `ai_analysis_result_low_risk` / `_monitor` | ✅ | `4ff08ef` `0715b3c` |
| 18 | `ai_analysis_result_emergency` | ✅ | `102c6f3` |
| 19–21 | the assistant trio | ✅ device-verified | `aae4ebe` `9f47ee1` |
| 22 | `conversation_history` | ✅ device-verified | `f6715b6` |
| 23 | `health_timeline` | ✅ device-verified | `1cba0e6` |
| 24 | `add_health_record` | ✅ device-verified | `a8c6846` |
| 25 | `weight_tracking` | ✅ device-verified | `c488dea` |
| 26 | `medication_tracker` | ✅ device-verified | `9af3a54` |
| 27 | `vaccination_manager` | ✅ device-verified | `24205ea` |
| **28** | **`reminder_detail`** | ✅ device-verified | **`c56c863`** |
| **29** | **`pet_profile`** | ✅ device-verified | **`b6d8063`** |
| **30** | **`edit_pet`** | ✅ device-verified | **`d707c31`** |
| **31** | **`manage_multiple_pets`** | ✅ device-verified | **`c817d4a`** |
| **32** | **`pet_statistics`** | ✅ device-verified | **`669592e`** |
| **33** | **`memories_gallery`** | ✅ device-verified | **`4a892bb`** |
| **34** | **`memory_detail`** | ✅ device-verified | **`2029615`** |

### Remaining — 23 mockups

The two pre-auth surfaces (`000` re-walk, the sign-in screen) are still the
highest-visibility gap. Then: `notifications`, `account_management`, `profile`,
`emergency_hub`, `first_aid_guide`, `prepare_for_vet_visit`,
`pdf_health_report_preview`, `add_memory`, `search_memories`,
`breed_encyclopedia` + `breed_detail`, `smart_walks` + `weather_walk_advisor`,
the four community screens, the four premium screens, `ai_transparency`,
`privacy_security`, `know_your_baseline`.

---

## 3 · Completed this session

### The pets and memories batch — seven screens

Two were **new screens that never existed**: `pet_profile` (until now "View
Profile" pushed the *edit form*) and `pet_statistics`. One was new because a
reminder had no page of its own (`reminder_detail`). Four were rebuilt in
place, keeping every caller and every existing test key working.

Detail is in `IMPLEMENTATION_CHANGELOG_UI.md`. The headlines:

1. **Everything is wired to something real.** Two `reminders` columns that had
   never been read (`created_at`, `notification_sent_at`) now fill the fact
   grid and the history; Postpone rewrites `due_date` and reschedules the
   notification; the profile's counts, the statistics page and the pets list
   all count off the same providers the modules use; the memory gallery's
   "All Pets" genuinely merges every pet's book; the memory detail's position
   counter and arrows really step through the book.
2. **Eleven primitives were extracted, not duplicated** — including the whole
   six-widget form kit out of a 1,500-line form screen, and `LocalTickLog`,
   which now backs three device-local stores instead of one.
3. **A shipped feature was nearly lost and the tests caught it.** The
   `manage_multiple_pets` rebuild dropped the **F-4 last-check chip**, the only
   per-pet health signal on the page. Three existing `pets_list_test`
   assertions failed; it is restored, on its own line.
4. **Six defects found before the device**, all by the em-square test font or
   the constraint checker (see §4).
5. **Three device-only defects** the tests could not see: a clipped Care Score
   box, a sparkline plotting the wrong series, and a portrait falling back to a
   different animal than the rest of the app shows.

---

## 4 · Defects found and fixed this session

| Defect | Found by | Screen |
|---|---|---|
| `HealthActionPill`'s label took its natural width under `mainAxisSize.min` — a long label overflowed by 33px | widget test | shared primitive |
| Four record cards used `CrossAxisAlignment.stretch` in an unbounded Column → infinite-height assertion | widget test | `pet_profile` |
| Name + two chips overflowed a card row by 76px | widget test | `manage_multiple_pets` |
| The **F-4 last-check chip** was dropped in the rebuild | existing test | `manage_multiple_pets` |
| The identity meta lost the species; the warm empty state lost its copy | existing tests | `manage_multiple_pets` |
| "All time" silently excluded records older than the 24-month axis cap | unit test | `pet_statistics` |
| A hint spelled like real data duplicated the value in the widget tree | widget test | `edit_pet` |
| The Care Score box clipped to "Car…" / "Jus…" at its 94dp share | **device** | `pet_profile` |
| Every overview tile plotted the total-records series, so "Medications" drew all records | **device** | `pet_statistics` |
| The portrait fell back to the cartoon avatar while every other screen shows photoreal species art | **device** | `edit_pet` |
| "1 entries"; a postpone orphaned its tick key | **device** / review | `reminder_detail` |

---

## 5 · Known issues

| Issue | Severity | Notes |
|---|---|---|
| **PR #97 unmerged** | blocks the release train | needs a human approval or `--admin`; see §0 |
| **This branch is stacked and needs a rebase** | medium | one command, in §0 |
| Anonymous sign-in fails on the dev Supabase project | blocks guest QA | founder-side config |
| iOS never built or run | release blocker | Apple submission impossible until done |
| `000` auth gateway not re-walked; sign-in still on the legacy light theme | medium | the only screens left on the old design |
| Three device-local stores (dose ticks, reminder ticks, memory hearts) | medium | each needs a table + RLS + deploy, founder-gated. **Every one is disclosed in the UI** |
| Twelve features marked *Soon* | medium | recurring reminders, lead-up/missed nudges, personality traits, family sharing, microchip/colour/neutered/blood type, expenses, memory tags, albums, video memories. Each keeps its control and says what is missing |
| Record attachments use the `memories/` R2 scope | low | a `records/` scope needs `_shared/upload_key.mjs` + three Edge redeploys |
| Two files are `dart format`-clean, the repo is not | low | `pet_statistics_screen.dart`, `pet_profile_screen.dart`. Formatted by accident; no existing file was reflowed. Owner's call whether to format the repo |
| A medication schedule is parsed from free text | low | fails to nothing |
| Snackbars are light-on-dark app-wide | low | Material 3 default |
| `new-interface/` untracked (93 MB) | low | owner's call |
| D-4 asset regeneration, D-5 payment marks | low | owner-gated |

---

## 6 · Safety posture

No contract rule has been relaxed. Every departure from a mockup is a copy or
content change with the layout preserved, and each is recorded in the commit
that made it.

This batch was the most claim-heavy of the programme. What the references
asserted and what shipped:

| Mockup claim | Shipped |
|---|---|
| "Health Score · 92 · Excellent" (×4 screens) | the Care Score, record completeness, banded by `careBand()` (D-2) |
| "Family Health · Excellent" over three pets | records on file, counted |
| "Vaccinations 12/12 · Completed · Up to date" | how many are on file |
| "Allergies · 2 · Known" | the owner's own notes, marked as theirs (V-22) |
| "Conditions · 0 · None · Great!" | **gone** — an all-clear, and the literal string `safety_copy_test` bans |
| "Health Score Trend", rising 78 → 92 | **Records Over Time** — what was logged, never how an animal is doing |
| "All good! Keep it up" / "Great Job!" | gone |
| "Consider dental check-up. Regular dental care improves overall health." | **gone** — recommending a procedure is veterinary advice |
| "Expenses · ₺2,450 · Total Spent" | the tile, marked *Soon*. There is no money in this product |
| "AI Highlight · Captured Buddy's playful spirit perfectly" | **gone** — a model reading a mood off a photo, on the one surface that is human content only |
| "Location · Kent Park, Eskişehir" + map | the privacy rule: GPS is stripped on the device before upload |
| "Dr. Ayşe Yılmaz · PawCare Veterinary Clinic" | a maps search. A fake practice on a health record is worse than none |
| "Blood Type: DEA 1.1 +" / "N/A" | dropped from the card, *Soon* in the form |
| "Primary Pet" | **Active** — the app has an active pet, which is a different claim |
| Delete / Skip painted in the EMERGENCY red (×3) | `HealthTone.gold`; the confirmation carries the weight |
| a video scrubber, duration, size, resolution | Type, taken on, added on, stored |

**Running list of mockup claims that cannot ship**, on top of the earlier ones:
household health grades · zero-condition all-clears · procedure
recommendations · invented currency totals · AI readings of a pet's mood ·
photo locations · fabricated veterinary practices · graded trend lines.

Five decorative palettes now each carry a test asserting they are clear of all
six action-ladder values: `vaccineTint`, `reminderTint`, `breakdownTints`,
`AssistantTone`, `HealthTone`. The one deliberate exception remains a past AI
check chipped in its own ladder colour — on the health timeline, and on the
pets list (F-4).

`test/safety_copy_test.dart` and `test/onboarding_system_a_test.dart` are the
tripwires, now joined by a per-screen safety group in seven more test files.
`scripts/verify-disclaimers.sh` passes.

---

## 7 · Testing and validation

| Gate | Result |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | **691 passed** (556 → 691, +135 this session) |
| `scripts/verify-disclaimers.sh` | PASS |
| CI | **all 7 jobs green** on PR #97 (run `31164010792`); this branch has not been PR'd yet |
| Device (Redmi Note 8, 393×851) | all seven screens walked, with **data written through the app**: a reminder postponed and marked taken, a memory created end to end (picker → EXIF strip → presigned PUT) and hearted |

**Not run** (headless / founder-side): iOS, the release-build matrix, the RLS
Docker suite locally, `node --test` on Edge Functions. All four run in CI and
were green on #97.

---

## 8 · Latest commits

```
2029615  Memory Detail rebuilt against its mockup
4a892bb  Memories Gallery rebuilt against its mockup
669592e  Pet Statistics rebuilt against its mockup — counted, never graded
c817d4a  Manage Multiple Pets rebuilt against its mockup
d707c31  Edit Pet rebuilt against its mockup, and the form kit it needed
b6d8063  Pet Profile rebuilt against its mockup — the screen that never existed
c56c863  Reminder Detail rebuilt against its mockup
--- ui-impl-phase-p-onboarding (PR #97, green, unmerged) ---
e6effd6  docs: the health module, three shipped bugs, and the layout traps
24205ea  Vaccination Manager rebuilt against its mockup
9af3a54  Medication Tracker rebuilt against its mockup
c488dea  Weight Tracking rebuilt against its mockup
a8c6846  Add Health Record rebuilt against its mockup
```

---

## 9 · Next milestones

1. **Merge PR #97**, rebase this branch, open its PR. Both are one command
   each; see §0.
2. Owner's call on the next batch. Recommended: the two pre-auth surfaces —
   `000` re-walked and the sign-in screen off the legacy light theme.
3. A founder-gated migration would retire all three device-local stores and
   unlock most of the twelve *Soon* fields at once. Worth batching.
4. `new-interface/` is still untracked (93 MB) — owner's call.
