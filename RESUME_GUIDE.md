# RESUME_GUIDE

**Read this first.** It is written so a fresh agent can continue in minutes
without asking questions.

**Last updated:** 2026-08-06 (later) · **Branch:** `ui-impl-phase-p-onboarding`
**Head:** `9f47ee1` · **Gates:** `flutter analyze` clean · 465 tests green ·
`verify-disclaimers` PASS

---

## 1 · Current phase

Rebuilding the app's screens against the reference mockups in `new-interface/`
(57 PNGs, untracked, ~93 MB). Onboarding, home, the AI Health Check flow, all
three result screens **and the assistant trio** are finished. **The current
batch is complete — 21 of 57 mockups implemented.**

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
| `ai_analysis_result_low_risk` + `_monitor` | `analysis/result_screen.dart` + `health_check/result_sections.dart` | `4ff08ef` `0715b3c` |
| `ai_analysis_result_emergency` | `analysis/emergency_result_screen.dart` | `102c6f3` |
| `ai_assistant_home` + `ai_assistant_chat` + `ai_message_actions` | `assistant/assistant_screen.dart` + `assistant/assistant_sections.dart` | `aae4ebe` `9f47ee1` |

All device-walked on the Redmi Note 8 (`AYXSUKIVJVPZ7HPZ`, 1080×2340 @440dpi =
**393×851 logical** — the same size the mockups are drawn at).

---

## 3 · Remaining work — start here

The assistant trio is done. **36 mockups remain**, none of them started. The
next batch is the owner's call; the two obvious candidates are:

### 3.1 · The two pre-auth surfaces still on old design

`000` (the auth gateway) was built but never re-walked against its mockup —
the shield overlaps the dog and the social-proof line ellipsises. The sign-in
screen is still on the legacy light theme, which is jarring against the rest
of the app. Both are visible to every new user before anything else.

### 3.2 · The rest of the set

`conversation_history`, `memories_gallery`, `breed_encyclopedia`,
`smart_walks`, `community_feed`, `premium_home`, `subscription_plans`,
`account_management`, `notifications`, `vaccination_manager`,
`medication_tracker`, `weight_tracking`, `pdf_health_report_preview`,
`prepare_for_vet_visit`, `first_aid_guide`, `emergency_hub`, `breed_detail`,
`pet_profile`, `pet_statistics`, `ai_transparency`, `privacy_security`, and
the remaining settings surfaces.

**`conversation_history` is the natural next one** — the assistant's "View
all" already opens a working sheet that has not been rebuilt against it, and
the primitives in `assistant_sections.dart` cover most of what it draws.

**Safety notes that constrain the assistant, if you touch it again:** V-23 —
the assistant must never imply a veterinary role (`safety_copy_test` bans
"vet assistant", "Dr. Paw", "virtual vet"). V-12 — suggestion chips must not
presuppose a symptom. And the assistant is deliberately **not** a second
triage entry point: symptoms belong in the Check flow, where the emergency
override, the quota rules and the action ladder all apply.

## 4 · Reusable primitives — extend these, do not duplicate

| Primitive | File | Use |
|---|---|---|
| `HomeCard`, `HomeCardHeader` | `home/home_sections.dart` | every dark slab and section heading in System B |
| `HomeListCard`, `HomeQuickActions`, `HomeStatStrip`, `PetRail`, `PetPortrait`, `HomeBrandBar`, `HomeGreeting`, `PetHeroPanel` | `home/home_sections.dart` | home, reusable elsewhere |
| `HealthCheckAppBar`, `HealthCheckSteps`, `healthCheckSteps4/5`, `HealthCheckDisclaimer`, `HealthCheckScaffold` — all take a `tint`, so the emergency screen runs the same chrome in red | `health_check/health_check_chrome.dart` | every screen in the check flow |
| `ResultHero`, `ResultActionCard`, `ResultSummaryCard`, `ResultListCard` (`lead`/`chip`), `ResultActionRow` (optional badge), `ResultActionBar`, `ResultTrendCard`, `ResultAssistantStrip` (icon/label/key), `ResultStatusCard`, `ResultGuideStrip`, `ResultReminderRow` | `health_check/result_sections.dart` | all three result screens |
| `BlendMask` | `theme/paw_components.dart` | composite a supplied plate rendered on black (`BlendMode.screen`) |
| `OnbPage` (pinned footer + adaptive gaps), `OnbSpacing`/`OnbGap`, `OnbNeonCard`, `OnbNeonGlyph`, `OnbHaloIcon`, `OnbCrest`, `OnbPhoneMockup`, `OnbSpeechBubble`, `OnbFloorGlow`, `OnbDashTether` | `onboarding/onboarding_ui.dart` | System A (onboarding) only |
| `AssistantAppBar`, `AssistantCircleButton`, `AssistantBrandPill`, `AssistantSectionHead`, `AssistantPawBadge`, `AssistantHaloPortrait`, `AssistantHero`, `AssistantPromptRow`/`AssistantPrompt`, `AssistantContinueCard`/`AssistantConversationRow`, `AssistantTopicsCard`/`AssistantTopic`, `AssistantGlanceCard`/`AssistantSignal`, `AssistantPremiumBanner`, `AssistantComposer`, `AssistantDisclaimer`, `AssistantPetBar`, `AssistantPrivacyStrip`, `AssistantDayChip`, `AssistantUserBubble`, `AssistantReplyBubble`, `AssistantHelpfulPrompt`, `AssistantSuggestionRail`, `AssistantActionSheet`/`AssistantAction`, `AssistantTone` | `assistant/assistant_sections.dart` | the assistant trio; the bubbles, composer and action sheet are reusable anywhere a conversation appears |
| `careScore(pet, hasCheck:, hasReminder:)` | `home/home_sections.dart` | the D-2 record-completeness dial — home, the result screen and the assistant all draw it |
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
   laziness hid content from tests and from screen readers alike. The
   *conversation*, by contrast, is a `reverse: true` `ListView.builder` — a
   thread is genuinely long and has to stay pinned to the newest turn.
7. **The assistant is one route with two surfaces**: the hub while
   `chat.isEmpty`, the conversation once a message exists. The app bar, the
   composer and the pinned footer are shared and parameterised, which is why
   `ai_assistant_home` and `ai_assistant_chat` are one implementation.
8. **Widget tests must set a handset surface.** The default test window is
   800×600 — wider and far shorter than any phone — so on a tall scrolling
   screen everything below the fold is never built and the assertions pass
   vacuously. `assistant_screen_test.dart` sets 393×851 (and 393×1500 where a
   test needs the whole page laid out in one pass).
9. **In `flutter_test` every glyph is a full em square.** A `Row` that fits
   comfortably on device can overflow by 50 points in a test. That is a
   feature: it found two real defects here (a pill and a CTA) before the
   device did. Make the label `Flexible` + `FittedBox`, do not widen the box
   to silence it.

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
- **The emergency surfaces** carry help contacts, first aid, the disclaimer and
  the acknowledgment gate (rule 4 / D-1) — **plus**, since owner decision
  **D-7**, the four sections `ai_analysis_result_emergency` adds, rewritten in
  PawDoc language. D-7's scope is `EmergencyResultScreen` only;
  `EmergencyHelpScreen` (the offline red button) stays model-free.
- **`EmergencyResultScreen` renders zero motion widgets, permanently** —
  `no_motion_on_safety_surfaces_test` fails the build otherwise. The pet
  appears as a still portrait, never the living rig.
- **The Health Score is a wellness metric only** (D-2) — it ships as "Care
  Score", computed from record completeness.
- **The action ladder's hues are safety-locked** and never repurposed as
  decoration; the floor is calm slate, never a reassuring green.
- Disclaimers are **API-injected** — the UI only gates on `disclaimerRequired`.
  The assistant's standing line under the composer is a *separate*, always-on
  UI disclaimer; `verify-disclaimers.sh` governs the result screens only.
- **The assistant never implies a veterinary role** (V-23) and its suggestion
  chips never presuppose a symptom (V-12). It is also not a second triage
  entry point — the "Health & Symptoms" topic ships as "Health & Records",
  because a symptom belongs in the Check flow where the emergency override,
  the quota rules and the action ladder all apply.
- **Decorative colour may never borrow an action-ladder hue.** The message
  action sheet is eight-coloured by design, and two of the mockup's choices
  land on the MONITOR amber and the EMERGENCY red. `AssistantTone` holds the
  substitutes and `assistant_screen_test.dart` pins the separation.

`test/safety_copy_test.dart` is load-bearing. **Do not weaken it to make a
screen pass** — scope it precisely instead.

---

## 8 · Device validation

```bash
# helper scripts live in the session scratchpad; recreate if absent
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

1. Ask the owner which batch is next. The two pre-auth surfaces (§3.1) are the
   highest-visibility gap; `conversation_history` is the cheapest, because the
   assistant's "View all" already opens a sheet that has not been rebuilt and
   `assistant_sections.dart` covers most of what that mockup draws.
2. Whatever it is: open the reference and read it in full before writing
   anything, then survey the target file and the primitives table in §4.
3. Build → `flutter analyze` → `flutter test` → hot-reload onto the Redmi →
   screenshot → compare → fix → commit → next screen.
4. Open a PR for this branch so CI runs; `main` is protected (linear history +
   review), so it must be squash-merged.
5. Update `RESUME_GUIDE.md`, `PROJECT_PROGRESS_SUMMARY.md` **and**
   `IMPLEMENTATION_CHANGELOG_UI.md` at the end of the session.

### How to reach the assistant surfaces on device

| Surface | How |
|---|---|
| hub (`ai_assistant_home`) | Home → the "AI Assistant" quick action, or the centre **+** → "Ask PawDoc AI" |
| conversation (`ai_assistant_chat`) | tap any opener chip, or type and send. The reply streams over SSE from the deployed `assistant-chat` Edge Function |
| action sheet (`ai_message_actions`) | scroll to the foot of any reply → the **…** button. The "Was this helpful?" pill sits under the newest reply until it is answered |
| the menus | the pet pill (profile / new thread), **More** in the pet bar, **History** for the conversation list |

### How to reach each result variant on device

The loading run holds a non-emergency result for ~33.5s, so budget ~40s.

| Variant | How |
|---|---|
| CALL_TODAY / monitor | pick "Skin irritation" + "Itching" on the details step |
| WATCH_AND_RECHECK | submit with almost no detail |
| GET_HELP_NOW | add a note like "belly hugely swollen and hard, retching with nothing coming up, very weak" — and note the **client** keyword router intercepts the hardcoded list first and lands on `EmergencyHelpScreen` instead, so use free text the router does not match |

The emergency gate blocks the back button until acknowledged — tap **Continue**
to leave, do not fight it with `input keyevent 4`.
