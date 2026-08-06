# PROJECT_PROGRESS_SUMMARY

Overall project status. Companion to `RESUME_GUIDE.md` (how to continue) and
`memory/UI_PROGRESS.md` (the UI programme's own record).

**Last updated:** 2026-08-06 (later) · **Branch:** `ui-impl-phase-p-onboarding` ·
**Head:** `9f47ee1`

---

## 1 · Where the product stands

PawDoc is feature-complete and pre-launch. Engineering reached "GO for a
50-user beta" in June; since then the work has been store-readiness, a device
QA programme, and — currently — rebuilding the interface against the
`new-interface/` reference set.

| Area | Status |
|---|---|
| Flutter app | builds, 465 tests green, analyze clean |
| AI service | deployed to Fly; Tier 2 Gemini → Tier 3 Claude |
| Supabase | 3 migrations + 9 Edge Functions deployed |
| Play | AAB 1.0.0+5 built and signed; internal testing configured |
| iOS | never built or run — hard blocker for an Apple release |
| Legal portal | live on AWS CloudFront, app-integrated |

---

## 2 · Screens rebuilt against the reference set

**21 of 57 mockups implemented.**

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

### Remaining

**36 mockups, none started.** The two pre-auth surfaces still on old design
(`000` re-walk, the sign-in screen) are the highest-visibility gap;
`conversation_history` is the cheapest next screen, because the assistant's
"View all" already opens a sheet that has not been rebuilt and
`assistant_sections.dart` covers most of what that mockup draws. After that:
memories, encyclopedia, walks, community, premium, account, notifications,
vaccination, medication, weight, PDF preview, vet prep, first aid, emergency
hub, breed detail, pet profile, statistics, AI transparency, privacy, and the
remaining settings surfaces.

---

## 3 · Completed this session (2026-08-06, later)

### The assistant trio — `aae4ebe`, `9f47ee1`

1. **`ai_assistant_home`** — the hub: hero with the orbit-lit pet and the
   privacy card, four openers, a resumable thread, six topic tiles, the
   at-a-glance card and the premium strip, over a pinned composer.
2. **`ai_assistant_chat`** — the conversation: pet bar with Private / History /
   More, privacy strip, day divider, tailed bubbles with timestamps and
   delivery ticks, a suggestion rail, the composer and the standing
   disclaimer. Same route as the hub — the surfaces swap on `chat.isEmpty`.
3. **`ai_message_actions`** — the per-reply action row (copy · 👍 · 👎 · …), the
   "Was this helpful?" pill under the newest reply, and the sheet: an eight-tile
   grid (Copy, Save to Diary, Share, Create Reminder, Helpful, Not Helpful,
   Regenerate, Report) plus "You might also ask" with a shuffle.
4. **Everything in the sheet does something real.** Copy → clipboard. Save to
   Diary → the health-event form, pre-filled (a new `initialNotes`
   parameter). Share → the system sheet. Create Reminder → the reminder form.
   Regenerate → a new `ChatController.regenerate()` that re-asks *through*
   `send()`, so the emergency router, the quota and the server checks all apply
   again. Report → the contact page. Helpful / Not Helpful are session-local
   and say so — there is no assistant-message feedback table, and pretending a
   rating was filed somewhere would be a claim the app cannot keep.
5. **Four defects found and fixed.** Two by the widget tests, before the device
   saw them (the View Details pill and the premium CTA both overflowed their
   rows — in `flutter_test` every glyph is a full em square, which is exactly
   the large-text case that would break on a real handset). Two on the device
   (the hero pet was a hard-edged photograph; the pet/More menus were opened
   transparent for their rounded corners and then never drew a panel).
6. **`careScore` moved to `home_sections.dart`.** Three surfaces now draw the
   same D-2 dial and a second implementation is how two of them end up
   disagreeing.

### Earlier the same day

1. **`ai_analysis_result_emergency` implemented** under owner decision **D-7**,
   which authorised rebuilding the four sections rule 4 had kept off the screen
   — rewritten in PawDoc language, never copied. `102c6f3`
2. **The low-risk / monitor result no longer reads thinner than its mockup.**
   The two list cards took the reference's weights (lead line + pill + list),
   the missing "When to see a vet?" strip was added, the reminder confirmation
   card replaced a greyed-out button, and the Care Score and trend sparkline
   are computed from real data instead of placeholders. `0715b3c`
3. Confirmed on device that **an EMERGENCY cuts straight through the 33.5s
   loading run** — it appeared at 23%, with no wait.
4. Confirmed on device that **the acknowledgment gate blocks the back button**
   (it refused `keyevent 4` until the checkbox was ticked).

### Fixed in the previous session

1. **Onboarding CTA below the fold** — every page opened with its Next button
   off-screen. `OnbPage` now pins the footer over a fade strip with the content
   scrolling beneath; the footer measures itself (a constant hid `002`'s trust
   card). Page-level gaps scale with the viewport; artwork and type never do.
   `295fff5`
2. **The analysis loading run was decoration** — the runner revealed the moment
   the request returned, so a warm response snapped past the screen at ~12%.
   The result is now held until the run reaches 100 (~33.5s), with an EMERGENCY
   and reduce-motion cutting straight through, and a parked-at-99 waiting state
   when the network runs long. `9820028`
3. **Three responsiveness defects** the home two-column layout exposed:
   `WalkCard` and `CommunityCard` rendering one character per line in a narrow
   column, an `IntrinsicHeight` that cannot measure a `LayoutBuilder` (blanked
   the whole block), and `PawPillButton` ellipsising half the grid. `3881f38`
4. **A reassuring green at the ladder's floor**, introduced mid-implementation
   on the result screen and caught before commit — the action card now takes
   the safety-locked hue, which is calm slate. `4ff08ef`
5. **Lazy list hid content from tests and screen readers** on the result
   screen. `4ff08ef`

### Fixed in the previous session (same branch)

6. **The add-pet step could not be passed** pre-auth (`create` reads
   `currentUser!.id`) — fixed with `PendingPet`, flushed in `RootShell`.
7. **Finishing onboarding looped back to the app-open screen** — it now exits
   to `/auth-gateway` when signed out.
8. **A System A leak**: `SpeciesChip` rendered its selection lime-on-navy.
9. **`onb-hero-dog-kitten-cutout` was a baked checkerboard**, not a cutout —
   the auth gateway had been drawing it. Keyed, eroded, feathered.

---

## 4 · Known issues

| Issue | Severity | Notes |
|---|---|---|
| Anonymous sign-in fails on the dev Supabase project | blocks guest QA | founder-side config |
| iOS never built or run | release blocker | Apple submission impossible until done |
| `000` auth gateway not re-walked against its mockup | medium | shield overlaps the dog; social-proof line ellipsises |
| Sign-in screen still on the legacy light theme | medium | jarring against the dark app; not yet in a batch |
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

`test/safety_copy_test.dart` (regex sweep over `lib/`) and
`test/onboarding_system_a_test.dart` are the tripwires. `scripts/verify-
disclaimers.sh` passes.

---

## 6 · Testing and validation

| Gate | Result |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | **465 passed** |
| `scripts/verify-disclaimers.sh` | PASS |
| `scripts/verify-no-placeholders.sh` | OK on overclaims; founder-fill items remain |
| Device (Redmi Note 8, 393×851) | every screen in §2 walked |
| CI | runs on PRs and `main` only — this branch has not triggered it |

**Not run** (headless / founder-side): iOS, the release-build matrix, the RLS
Docker suite, `node --test` on Edge Functions.

---

## 7 · Latest commits

```
9f47ee1  Assistant: the device pass on the conversation and the action sheet
aae4ebe  Assistant rebuilt against ai_assistant_home / _chat / _message_actions
bfa7583  docs: emergency result (D-7) and the result-screen fill-out
0715b3c  Result screens: fill the gaps the safety rewrite left behind
102c6f3  Emergency result rebuilt against its mockup (owner decision D-7)
eea3037  docs: RESUME_GUIDE + PROJECT_PROGRESS_SUMMARY
4ff08ef  Result screen rebuilt against ai_analysis_result_low_risk / _monitor
9820028  Analysis loading: the run finishes before the result appears
972f6e8  docs: home + AI Health Check flow, and the pinned onboarding CTA
6eb63e5  AI Health Check: the four-screen guided flow
3881f38  Home rebuilt against mockup 010
295fff5  Onboarding: pin the CTA, and let the vertical rhythm breathe
16db312  docs: onboarding 004-009 complete
76b9988  Onboarding 008 + 009: the add-pet page, the welcome page, and two blockers
e61aab5  Onboarding 006 + 007: the two assistant pages, one per mockup
699f503  Onboarding 004 + 005: glass compare cards, diary composition
```

---

## 8 · Next milestones

1. Owner's call on the next batch. Recommended: `conversation_history` (the
   assistant's "View all" already opens an un-rebuilt sheet), then the two
   pre-auth surfaces — `000` re-walked and the sign-in screen re-skinned off
   the legacy light theme.
2. Open a PR for this branch so CI runs; `main` is protected (linear history +
   review), so it must be squash-merged.
3. `new-interface/` is still untracked (93 MB) — owner's call whether it lands
   in the repo or stays out.
