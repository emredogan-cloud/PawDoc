# PROJECT_PROGRESS_SUMMARY

Overall project status. Companion to `RESUME_GUIDE.md` (how to continue) and
`IMPLEMENTATION_CHANGELOG_UI.md` (what changed, screen by screen).

**Last updated:** 2026-08-08 · **Branch:** `ui-batch-s-community-emergency` ·
**Head:** `8e418e8`

---

## 0 · One thing needs a human

PR #98 merged (squash, `35a6ff5`); this branch was cut from that `main` and
carries the community + emergency batch. GitHub refuses PR-author
self-approval, so its merge needs a human approval or
`gh pr merge --squash --admin`.

**One decision was taken this session and should be reviewed.** PawDoc's
community has no posts table, so the three post mockups (`community_feed`,
`community_post_detail`, `create_post`) were mapped onto the real graph —
connections, the 1:1 thread, walk proposals, the profile — rather than shipped
as inert shells. Post-only controls keep their place and say *Soon*. If the
intent was a faithful posting shell awaiting a migration, say so and it can be
rebuilt that way.

---

## 1 · Where the product stands

PawDoc is feature-complete and pre-launch. Engineering reached "GO for a
50-user beta" in June; since then the work has been store-readiness, a device
QA programme, and — currently — rebuilding the interface against the
`new-interface/` reference set.

| Area | Status |
|---|---|
| Flutter app | builds, **852 tests** green, analyze clean |
| AI service | deployed to Fly; Tier 2 Gemini → Tier 3 Claude |
| Supabase | 3 migrations + 9 Edge Functions deployed |
| Play | AAB 1.0.0+5 built and signed; internal testing configured |
| iOS | never built or run — hard blocker for an Apple release |
| Legal portal | live on AWS CloudFront, app-integrated |

---

## 2 · Screens rebuilt against the reference set

**47 of 57 mockups implemented.** (41 before this session, +6.)

| # | Mockup | Status | Commit |
|---|---|---|---|
| 1–34 | everything through `memory_detail` | ✅ device-verified | see `RESUME_GUIDE.md` §2 |
| **35** | **`add_memory`** | ✅ device-verified, end to end | **`b5b4647`** |
| **36** | **`search_memories`** | ✅ device-verified | **`149ac4d`** |
| **37** | **`smart_walks`** | ✅ device-verified against live MET data | **`450d356`** |
| **38** | **`weather_walk_advisor`** | ✅ device-verified against live MET data | **`450d356`** |
| **39** | **`know_your_baseline`** | ✅ device-verified against Buddy's real record | **`dbbdcd3`** |
| **40** | **`breed_encyclopedia`** | ✅ device-verified | **`82d2cf6`** |
| **41** | **`breed_detail`** | ✅ device-verified | **`82d2cf6`** |

### Remaining — 16 mockups

The two pre-auth surfaces (`000` re-walk, the sign-in screen) are still the
highest-visibility gap. Then: `notifications`, `account_management`, `profile`,
`emergency_hub`, `first_aid_guide`, `prepare_for_vet_visit`,
`pdf_health_report_preview`, the four community screens, the four premium
screens, `ai_transparency`, `privacy_security`.

---

## 3 · Completed this session

### Seven screens, in five commits

Four were **new screens that never existed**: `add_memory` (the journal's "+"
opened a half-height frosted sheet), `search_memories`,
`weather_walk_advisor` and `know_your_baseline`. Three were rebuilt in place —
`smart_walks`, `breed_encyclopedia`, `breed_detail` — keeping every caller and
every route working.

Detail is in `IMPLEMENTATION_CHANGELOG_UI.md`. The headlines:

1. **This was the batch where the references stopped being merely unsupported
   and started being dangerous.** `know_your_baseline` prints real published
   veterinary reference ranges (60–100 bpm, 38.0–39.2 °C) captioned as *your
   pet's* normal; both breed pages grade named conditions "Risk: Moderate" on a
   page whose most likely reader owns that breed; both walk pages prescribe
   exercise duration and distance, branded as AI. Every one of those is gone,
   and §6 lists what replaced it.
2. **Almost everything that survived is counted.** The search screen's result
   total and every Quick Search chip's tally; the walk screens' comfort scores
   and five-day outlook, from live MET data scored on the device by a pure
   function; the baseline's observed weight range, record totals, longest gap
   and days since the last entry; the breed guide's four orders and its
   similar-breed matching. Nothing on any of the seven is asserted.
3. **The reference's "up to 10 photos" is real.** `pet_memories` holds one
   photo per row, so a multi-photo pick writes one entry per photograph — the
   review step says so before anything is written, the strip drags to reorder,
   and the free-tier allowance is checked against the whole batch.
4. **Six shipped defects fixed on the way** (§4) — including three separate
   states of the home walk card that had never been adapted to the two-column
   layout, one of which rendered *one character per line*.
5. **Eleven new reusable pieces**, five of them new shared modules, and two
   pre-existing duplications collapsed.

---

## 4 · Defects found and fixed this session

| Defect | Found by | Where |
|---|---|---|
| `HealthPrimaryCta` accepted an `icon` and drew a hardcoded `plus` — the journal's "See Premium" rendered its crown as a **+** | code review | shared primitive |
| The home walk card's **permission** state rendered **one character per line**; its **ready** state five. Only `WalksInitial` had ever been adapted to home's ~170dp column | **device** | `walk_card.dart` |
| A missing breed asset **threw** — five bare `Image.asset` call sites, so a renamed file would take the page down | widget test | `encyclopedia/` |
| The Care Score read **29** on the baseline screen and **43** on the timeline for the same pet | **device** | `baseline_screen.dart` |
| The health module menu overflowed by 132px once a seventh row was added | **device** | `history_timeline_screen.dart` |
| The five-day outlook labelled a 34 °C day "Ideal" from its 06:00 sample — an invitation to walk at noon | **device** review | `walk_sections.dart` |
| "Start a Walk · Soon" truncated to "Start a Walk · …" at its 5-share | **device** | `walks_screen.dart` |
| "Kind hours today" clipped, and counted only the hours *left* | **device** | `walks_screen.dart` |
| A three-button header ellipsised "Memories Gallery" | **device** | `memories_screen.dart` |
| The walk badge column, the outlook tile and the hour chip each overflowed at the em-square font | widget test | `walks/` |
| The privacy tiles stacked their glyph above the label; the reference sets it beside | **device** | `add_memory_screen.dart` |
| Life expectancy overflowed its card by 1.3px | widget test | `breed_detail_screen.dart` |

---

## 5 · Known issues

| Issue | Severity | Notes |
|---|---|---|
| **This branch has no PR** | blocks the release train | one command; see §0 |
| Anonymous sign-in fails on the dev Supabase project | blocks guest QA | founder-side config |
| iOS never built or run | release blocker | Apple submission impossible until done |
| `000` auth gateway not re-walked; sign-in still on the legacy light theme | medium | the only screens left on the old design |
| Six device-local stores (dose ticks, reminder ticks, memory hearts, recent searches, saved breeds, weight target) | medium | each needs a table + RLS + deploy, founder-gated. **Every one is disclosed in the UI** |
| ~20 features marked *Soon* | medium | the largest single unlock is **walk tracking**, which alone fills the walk log, the weekly totals and the milestones |
| Record attachments use the `memories/` R2 scope | low | a `records/` scope needs `_shared/upload_key.mjs` + three Edge redeploys |
| The repo is not `dart format`-clean | low | hand-formatted at 80 columns. Owner's call |
| A medication schedule is parsed from free text | low | fails to nothing |
| Snackbars are light-on-dark app-wide | low | Material 3 default |
| `new-interface/` untracked (93 MB) | low | owner's call |
| D-4 asset regeneration, D-5 payment marks | low | owner-gated |

---

## 6 · Safety posture

No contract rule has been relaxed. Every departure from a mockup is a copy or
content change with the layout preserved, and each is recorded in the commit
that made it.

**This batch was the most claim-heavy of the programme by a wide margin**, and
the first where a reference's claims were actively unsafe rather than merely
unsupported. What the references asserted and what shipped:

| Mockup claim | Shipped |
|---|---|
| "Resting Heart Rate · **60 – 100 bpm** · Your Pet's Normal Range" | **nothing.** A published reference range captioned as *this animal's* normal is medical content the app has no standing to publish; a reader who then counts 105 at home draws the conclusion PawDoc exists to route to a vet |
| "Body Temperature · 38.0 – 39.2 °C", "Respiratory Rate · 15 – 30" | the same — the tiles keep their place and say *Not tracked*, naming the actual reason |
| "Baseline Strength · 92/100 · Excellent" | the Care Score — record completeness, banded by `careBand()` (D-2), computed identically to the timeline's |
| "Everything looks good! Buddy's vitals are stable and well within his normal range" | what the record holds, counted |
| "Alerts Triggered · 0" | **gone** — it says the app is watching. The page states outright that it is not |
| "Consistency · 92%" | the longest gap, in days |
| "Great consistency! Keep up the good work!" | observations, counted. A test bans praise vocabulary in every one |
| "Most active time · 5 PM – 8 PM" | **gone** — nothing tracks activity |
| "View Warning Signs" | **Start a health check** — an ungated symptom list is the one thing this product must not hand out |
| "Hip Dysplasia · **Risk: Moderate**" ×5, with dot meters | the catalogue's own hedged notes, under **What Vets Watch For**, with no grade and the standing line that this is not about your pet |
| "Popularity · #3 · AKC Rankings", "FCI Group 8", "AKC Recognition 1925" | **gone** — none is in the catalogue and citing a registry's is fabrication |
| "Trainability ★4.7", "Good With Kids 5/5", "Watchdog Ability 2/5" | the two levels the catalogue actually authors |
| "Nutrition · High quality dog food" | the coat description. Dietary advice needs a source |
| "With proper care… can live a long, healthy and happy life" | the range, and that it is not a prediction |
| "**AI** Walk Suggestion: up to **60 minutes a day** is ideal for heart health and weight control" | **gone twice over** — an exercise prescription, branded as a model that does not exist |
| "Estimated duration 30 – 45 min" · "Ideal distance 3 – 5 km" | the kindest hours, the ground, the water and the sun — over one line saying how far and how long is the vet's call |
| "Give a water break every 15 – 20 minutes" | "Carry water and offer it whenever you stop" |
| "215 kcal burned" · "Calorie Hunter · 312/500" | **gone** — it needs weight, gait and metabolism |
| badges for "Walk 50 km" / "Walk 100 km" | milestones about the owner's habit. This app does not set distance targets for an animal |
| "All Locations" filter + a place under every result | the owner's own hearts. **EXIF and GPS are stripped on the device**; the sheet states the rule |
| "Family" / "Public" memory sharing | drawn, marked *Soon*. Every row is RLS-scoped — **private here is a description of the table, not a preference** |
| "Take Breed Match Quiz" | the card, marked *Soon* |

**Running list of mockup claims that cannot ship**, on top of the earlier ones:
published reference ranges presented as a pet's own · graded risks beside named
conditions · exercise prescriptions · a deterministic function branded as AI ·
burned calories · invented registry fields · implied monitoring and alerting ·
ungated symptom lists · distance targets for an animal · photo locations.

Six decorative palettes now each carry a test asserting they are clear of all
six action-ladder values: `vaccineTint`, `reminderTint`, `breakdownTints`,
`AssistantTone`, `HealthTone` and **`WalkBand`**. The one deliberate exception
remains a past AI check chipped in its own ladder colour — on the health
timeline, and on the pets list (F-4).

`test/safety_copy_test.dart` and `test/onboarding_system_a_test.dart` are the
tripwires, now joined by a per-screen safety group in five more test files.
`scripts/verify-disclaimers.sh` passes.

---

## 7 · Testing and validation

| Gate | Result |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | **852 passed** (784 → 852, +68 this session) |
| `scripts/verify-disclaimers.sh` | PASS |
| CI | not yet run on this branch — no PR exists |
| Device (Redmi Note 8, 393×851) | all seven screens walked, with **data written through the app**: a two-photo memory batch created end to end (picker → EXIF strip → presigned PUT → two rows), a search submitted and recalled from history, live MET forecasts fetched on device for both walk screens, and the baseline read against Buddy's real 18-record history |

**Not run** (headless / founder-side): iOS, the release-build matrix, the RLS
Docker suite locally, `node --test` on Edge Functions. All four run in CI.

---

## 8 · Latest commits

```
82d2cf6  Breed Encyclopedia and Breed Detail rebuilt against their mockups
dbbdcd3  Know Your Baseline rebuilt against its mockup — measured, never assumed
450d356  Smart Walks and the Weather Walk Advisor, rebuilt against their mockups
149ac4d  Search Memories rebuilt against its mockup — counted, never asserted
b5b4647  Add Memory rebuilt against its mockup — the sheet becomes a wizard
6a58f90  docs: the pets and memories batch, and the two open handoffs
--- main (PR #97 merged as 2a1cc11) ---
```

---

## 9 · Next milestones

1. **Open and merge the PR** for this branch; see §0.
2. Owner's call on the next batch. Recommended: the two pre-auth surfaces —
   `000` re-walked and the sign-in screen off the legacy light theme.
3. A founder-gated migration would retire all six device-local stores and
   unlock most of the *Soon* fields at once. **Walk tracking is the largest
   single unlock** — the walk log, the weekly totals and the milestones all
   depend on it and nothing else.
4. `new-interface/` is still untracked (93 MB) — owner's call.
