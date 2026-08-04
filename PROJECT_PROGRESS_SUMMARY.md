# PROJECT_PROGRESS_SUMMARY

Overall project status. Companion to `RESUME_GUIDE.md` (how to continue) and
`memory/UI_PROGRESS.md` (the UI programme's own record).

**Last updated:** 2026-08-04 · **Branch:** `ui-impl-phase-p-onboarding` ·
**Head:** `4ff08ef`

---

## 1 · Where the product stands

PawDoc is feature-complete and pre-launch. Engineering reached "GO for a
50-user beta" in June; since then the work has been store-readiness, a device
QA programme, and — currently — rebuilding the interface against the
`new-interface/` reference set.

| Area | Status |
|---|---|
| Flutter app | builds, 453 tests green, analyze clean |
| AI service | deployed to Fly; Tier 2 Gemini → Tier 3 Claude |
| Supabase | 3 migrations + 9 Edge Functions deployed |
| Play | AAB 1.0.0+5 built and signed; internal testing configured |
| iOS | never built or run — hard blocker for an Apple release |
| Legal portal | live on AWS CloudFront, app-integrated |

---

## 2 · Screens rebuilt against the reference set

**14 of 57 mockups implemented.**

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
| 16 | `ai_analysis_result_low_risk` | ✅ | `4ff08ef` |
| 17 | `ai_analysis_result_monitor` | ✅ (same implementation, ladder-parameterised) | `4ff08ef` |

### Remaining in the current batch

| Mockup | Target file | Notes |
|---|---|---|
| `ai_analysis_result_emergency` | `analysis/emergency_result_screen.dart` | four blocks cannot ship — see RESUME_GUIDE §3.1 |
| `ai_assistant_home` | `assistant/assistant_screen.dart` | V-23 / V-12 apply |
| `ai_assistant_chat` | `assistant/assistant_screen.dart` | |
| `ai_message_actions` | assistant message sheet | |

### Not yet started

40 further mockups: memories, encyclopedia, walks, community, premium,
account, notifications, vaccination, medication, weight, PDF preview, vet prep,
first aid, emergency hub, breed detail, pet profile, statistics, and the
remaining settings surfaces.

---

## 3 · Fixed this session

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
| Result "Save Report" marked *Soon* | low | PDF export exists for vet prep, not per-result |
| Home hero Energy/Mood/Activity marked *Soon* | low | nothing records them yet |
| `new-interface/` untracked (93 MB) | low | owner's call |
| D-4 asset regeneration (6 gaps), D-5 payment marks | low | owner-gated |

---

## 5 · Safety posture

No contract rule has been relaxed. Every departure from a mockup is a copy or
content change with the layout preserved, and each is recorded in the commit
that made it. The running list of mockup claims that cannot ship:

confidence percentages · risk levels · severity grades · differentials with
probabilities · named conditions · asserted causes · all-clear headlines and
checklists · clinical health scores · anything added to an emergency surface.

`test/safety_copy_test.dart` (regex sweep over `lib/`) and
`test/onboarding_system_a_test.dart` are the tripwires. `scripts/verify-
disclaimers.sh` passes.

---

## 6 · Testing and validation

| Gate | Result |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | **453 passed** |
| `scripts/verify-disclaimers.sh` | PASS |
| `scripts/verify-no-placeholders.sh` | OK on overclaims; founder-fill items remain |
| Device (Redmi Note 8, 393×851) | every screen in §2 walked |
| CI | runs on PRs and `main` only — this branch has not triggered it |

**Not run** (headless / founder-side): iOS, the release-build matrix, the RLS
Docker suite, `node --test` on Edge Functions.

---

## 7 · Latest commits

```
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

1. `ai_analysis_result_emergency` — with the rule-4 omissions surfaced to the
   owner as a decision, not a footnote.
2. The assistant trio (`ai_assistant_home`, `ai_assistant_chat`,
   `ai_message_actions`).
3. Re-walk `000` and re-skin the sign-in screen, which are the two remaining
   pre-auth surfaces still on old design.
4. Open a PR for this branch so CI runs; `main` is protected (linear history +
   review), so it must be squash-merged.
