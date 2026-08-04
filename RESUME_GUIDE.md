# RESUME_GUIDE

**Read this first.** It is written so a fresh agent can continue in minutes
without asking questions.

**Last updated:** 2026-08-04 · **Branch:** `ui-impl-phase-p-onboarding`
**Head:** `4ff08ef` · **Gates:** `flutter analyze` clean · 453 tests green ·
`verify-disclaimers` PASS

---

## 1 · Current phase

Rebuilding the app's screens against the reference mockups in `new-interface/`
(57 PNGs, untracked, ~93 MB). Onboarding is finished; home and the AI Health
Check flow are finished; the result screen is finished. **Three screens
remain in the current batch.**

Working method, unchanged from onboarding and expected to continue:

> read the reference → implement at full fidelity → `flutter analyze` →
> `flutter test` → hot-reload onto the Redmi → screenshot → compare →
> fix → commit → next screen.

---

## 2 · Completed screens

| Mockup | Implementation | Commit |
|---|---|---|
| `0001-app-first-screen` | `onboarding/first_run_screen.dart` | `70b8aa1` |
| `000` auth gateway | `onboarding/auth_gateway_screen.dart` | `70b8aa1` |
| `002`–`009` onboarding | `onboarding/onboarding_flow.dart` + `onboarding_stages.dart` + `onboarding_ui.dart` | `e26b441` `dc67e5e` `699f503` `e61aab5` `76b9988` `295fff5` |
| `010-home-page` | `home/home_screen.dart` + `home/home_sections.dart` | `3881f38` |
| `ai_health_check_start` | `health_check/health_check_start_screen.dart` | `6eb63e5` |
| `photo_analysis_upload` | `health_check/health_check_photo_screen.dart` | `6eb63e5` |
| `symptom_selection` | `health_check/health_check_symptoms_screen.dart` | `6eb63e5` |
| `ai_analysis_loading` | `health_check/health_check_loading_view.dart` | `6eb63e5` `9820028` |
| `ai_analysis_result_low_risk` + `_monitor` | `analysis/result_screen.dart` + `health_check/result_sections.dart` | `4ff08ef` |

All device-walked on the Redmi Note 8 (`AYXSUKIVJVPZ7HPZ`, 1080×2340 @440dpi =
**393×851 logical** — the same size the mockups are drawn at).

---

## 3 · Remaining work — start here

### 3.1 · `ai_analysis_result_emergency.png` — NEXT

Restyle `analysis/emergency_result_screen.dart` (179 lines) to the mockup.

**Reproduce:** the red node rail, the "This could be serious" hero with the
photo card, the "What to do now" four-tile help grid (Call a Vet Now · Find
24/7 Vet · Directions · Set Alert), the "While you're on the way" first-aid
rows, "View Full First Aid Guide", the acknowledgment CTA ("I Understand, Take
Me to Help"), and the footer disclaimer.

**Do NOT reproduce** — CLAUDE.md rule 4 and owner decision D-1 forbid anything
on an emergency surface beyond help contacts, first aid, the disclaimer and the
acknowledgment gate:

- "Emergency Risk Level · High" — a severity grade
- "Why it's serious:" list — AI-driven content naming conditions ("possible
  infection", "Swelling or irritation detected")
- "Potential Concern: Skin Infection" — `safety_copy_test` bans both
  `potential concern` and `skin infection` by regex
- "Health Score 36 · At Risk" — a meter on the red path (D-2 + rule 4)
- "Share this report … for faster diagnosis" — not one of the four permitted
  categories, and the copy says "diagnosis"

**This is the largest single deviation in the programme. Surface it to the
owner rather than burying it in a commit body.**

### 3.2 · `ai_assistant_home.png`

Target: `assistant/assistant_screen.dart`. Not yet read in detail — open the
reference first.

### 3.3 · `ai_assistant_chat.png`

Target: `assistant/assistant_screen.dart` (the conversation view).

### 3.4 · `ai_message_actions.png`

Target: the assistant's per-message action sheet. Check `assistant/` for an
existing long-press affordance before adding one.

**Safety notes for the assistant trio:** V-23 — the assistant must never imply
a veterinary role (`safety_copy_test` bans "vet assistant", "Dr. Paw", "virtual
vet"). V-12 — suggestion chips must not presuppose a symptom ("why is my dog…",
"what's wrong with…" are banned).

---

## 4 · Reusable primitives — extend these, do not duplicate

| Primitive | File | Use |
|---|---|---|
| `HomeCard`, `HomeCardHeader` | `home/home_sections.dart` | every dark slab and section heading in System B |
| `HomeListCard`, `HomeQuickActions`, `HomeStatStrip`, `PetRail`, `PetPortrait`, `HomeBrandBar`, `HomeGreeting`, `PetHeroPanel` | `home/home_sections.dart` | home, reusable elsewhere |
| `HealthCheckAppBar`, `HealthCheckSteps`, `healthCheckSteps4/5`, `HealthCheckDisclaimer`, `HealthCheckScaffold` | `health_check/health_check_chrome.dart` | every screen in the check flow |
| `ResultHero`, `ResultActionCard`, `ResultSummaryCard`, `ResultListCard`, `ResultActionRow`, `ResultActionBar`, `ResultTrendCard`, `ResultAssistantStrip` | `health_check/result_sections.dart` | result screens |
| `BlendMask` | `theme/paw_components.dart` | composite a supplied plate rendered on black (`BlendMode.screen`) |
| `OnbPage` (pinned footer + adaptive gaps), `OnbSpacing`/`OnbGap`, `OnbNeonCard`, `OnbNeonGlyph`, `OnbHaloIcon`, `OnbCrest`, `OnbPhoneMockup`, `OnbSpeechBubble`, `OnbFloorGlow`, `OnbDashTether` | `onboarding/onboarding_ui.dart` | System A (onboarding) only |
| `PawCard`, `PawPanel`, `PawPillButton`, `PawPrimaryButton`, `PawBackground`, `PawTone` | `theme/paw_components.dart`, `theme/paw_ui.dart` | app-wide |

---

## 5 · Architecture decisions in force

1. **Two visual systems.** System A = onboarding (navy / emerald / cyan).
   System B = the product (near-black / lime). Declared at the app root;
   onboarding overrides to A. `system_isolation_test.dart` pins the boundary.
2. **The mockups are AI-rendered pictures, not exported frames.** Their body
   copy measures ~9-12dp and rail labels ~8dp — unreadable on a handset. Match
   layout, spacing and composition exactly; set type ~15% above the naive
   scale. Page gutter is 18dp (measured), not 20.
3. **Pinned footers.** Onboarding uses `OnbPage`; the check flow uses
   `HealthCheckScaffold`. Both scroll content under an opaque action plate so
   the CTA is reachable on the first frame.
4. **`PendingPet`** holds the onboarding pet until there is a session; flushed
   in `RootShell.initState`, which is the first authenticated surface every
   sign-in path reaches.
5. **The analysis wait is deliberate** (~33.5s). See §6.
6. **The result body is a Column in a scroll view**, not a lazy ListView —
   laziness hid content from tests and from screen readers alike.

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
time. Express test pumps against that.

---

## 7 · Safety rules that constrain every screen

Read `CLAUDE.md` in full. The ones that bite in UI work:

- **Confidence is never rendered.** Ever. `safety_copy_test.dart` greps for it.
- **No differential, no percentages, no risk level, no severity grade.**
- **Never name a condition** and never assert a cause.
- **No output terminates without an action and a timeframe**; never render
  "normal" or any all-clear.
- **Nothing may be added to the emergency surfaces** beyond help contacts,
  first aid, the disclaimer and the acknowledgment gate (rule 4 / D-1).
- **The Health Score is a wellness metric only** (D-2) — it ships as "Care
  Score", computed from record completeness.
- **The action ladder's hues are safety-locked** and never repurposed as
  decoration; the floor is calm slate, never a reassuring green.
- Disclaimers are **API-injected** — the UI only gates on `disclaimerRequired`.

`test/safety_copy_test.dart` is load-bearing. **Do not weaken it to make a
screen pass** — scope it precisely instead.

---

## 8 · Device validation

```bash
# helper scripts live in the session scratchpad; recreate if absent
export ANDROID_SERIAL=AYXSUKIVJVPZ7HPZ          # Redmi Note 8, 393x851 logical
cd mobile
set -a; . ../.env; set +a
flutter run -d AYXSUKIVJVPZ7HPZ --debug --pid-file=/tmp/flutter.pid \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
kill -SIGUSR1 $(cat /tmp/flutter.pid)   # hot reload
kill -SIGUSR2 $(cat /tmp/flutter.pid)   # hot restart
adb exec-out screencap -p > shot.png
```

A second Redmi (`jfzxugsgnnvsrsg6`, 1080×2408) is also attached — pin
`ANDROID_SERIAL` or adb errors with "more than one device".

---

## 9 · Blockers and environment notes

- **Anonymous sign-in fails** on the dev Supabase project ("Could not start a
  guest session"). Device validation goes through an email account:
  `uiqa.aug04@example.com` / `PawDoc!2026qa`. Founder-side config, not a code
  defect.
- `flutter run` drops its session after long idles — relaunch, do not assume
  hot reload landed.
- CI only runs on `pull_request` and pushes to `main`; a branch push alone does
  not trigger it.
- `new-interface/` is still untracked — owner's call.

---

## 10 · Next recommended action

1. Open `new-interface/ai_analysis_result_emergency.png`.
2. Restyle `analysis/emergency_result_screen.dart` per §3.1, keeping every
   permitted block and omitting the four forbidden ones.
3. Validate on the Redmi through a real emergency check (type a keyword the
   offline router matches — see `emergency_keywords.dart`).
4. Commit, then take the assistant trio in order.
5. Update this file and `PROJECT_PROGRESS_SUMMARY.md` at the end of the session.
