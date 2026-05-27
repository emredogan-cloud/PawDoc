# 19 — Beta & Launch (Phase 2.3)

> Step-by-step for the founder: build & upload binaries via the Phase 0.4 Fastlane
> lanes, run a 50-user TestFlight beta, clear the **≥ 4.0** rating gate, submit to both
> stores, and — only after the legal gate clears — go public.
>
> 🚫 **HARD GATE.** The final "Release to Public" step is **STRICTLY BLOCKED** until
> every item in [`18-legal-and-launch-gate.md`](18-legal-and-launch-gate.md) §1 is
> done: **E&O insurance bound, attorney-reviewed ToS/Privacy live, veterinary
> practice-law review (CR #24), and the CR #9 retention decision.** Beta testing and
> store *submission* may proceed now; **public availability may not.**

## 0. Preconditions

- Phase **2.1** (polished build) and **2.2** (legal templates + gate runbook) merged.
- Release secrets present in the CI/Doppler environment (all from runbook 11):
  `MATCH_PASSWORD`, `MATCH_GIT_URL`, `MATCH_GIT_BASIC_AUTHORIZATION`,
  `APP_STORE_CONNECT_API_KEY_KEY_ID` / `_ISSUER_ID` / `_KEY`,
  `GOOGLE_PLAY_JSON_KEY_FILE`, `FASTLANE_APPLE_ID`, `APPLE_DEVELOPER_TEAM_ID`.
- Store metadata ready: [`docs/store_metadata/ios_app_store.md`](../store_metadata/ios_app_store.md)
  and [`docs/store_metadata/google_play.md`](../store_metadata/google_play.md).
- Screenshots produced in the exact order documented in those files (slots 1–5).

## 1. Build & upload the iOS beta (TestFlight)

The `beta` lane (see `fastlane/Fastfile`, relocated to `mobile/ios/fastlane` in 1.1)
authenticates with the App Store Connect API key, pulls signing certs via `match`
(readonly), builds the `Runner` scheme, and uploads to TestFlight.

```bash
# Preferred: CI-triggered by a git tag (release.yml calls `beta`)
git tag v0.1.0-beta.1 && git push origin v0.1.0-beta.1

# Or locally, from the iOS app dir:
cd mobile/ios && bundle exec fastlane beta
```
A processed build appears in App Store Connect → TestFlight within ~5–30 min.

## 2. Build & upload the Android beta (Play internal track)

The `play_internal` lane uploads the Flutter-built AAB to Play's **internal** track
(metadata/screenshots are uploaded separately — see §6).

```bash
# Build the release AAB (Flutter), then upload:
cd mobile && flutter build appbundle --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY   # + POSTHOG/REVENUECAT/ONESIGNAL/SENTRY
cd mobile/android && bundle exec fastlane play_internal
```

## 3. Onboard 50 TestFlight beta users

1. App Store Connect → TestFlight → create an **External** group "Beta 50".
2. Add a **public TestFlight link** (easiest for recruiting) or invite emails directly.
3. Fill **Test Information**: what to test, the disclaimer, and the feedback channel
   (`support@pawdoc.app`). External testers require Apple's first-build review (~24h).
4. Recruit to **50 active testers** (over-invite ~30% — not everyone installs).
5. Android: promote the same build to a Play **closed testing** track and invite a
   parallel cohort if you want cross-platform signal.

## 4. The ≥ 4.0 rating gate (how to actually measure it)

TestFlight has **no star ratings** (those only exist on the public store). So measure
the gate with an explicit in-beta survey and track it deliberately:

- Trigger an in-app **"Rate your experience 1–5"** prompt after a tester's 2nd analysis
  (or send a short form to the cohort via `support@pawdoc.app`).
- Require a meaningful sample: **≥ 30 of the 50** testers responding.
- **Gate to clear before public release:** mean rating **≥ 4.0** AND **zero open P0 bugs.**

Track it here each beta build:

| Build | Testers active | Ratings collected | Mean rating | Open P0 | Gate |
|-------|----------------|-------------------|-------------|---------|------|
| v0.1.0-beta.1 | | | | | ⬜ |

**P0 (release-blocking) bug — PawDoc definition:** a missed/under-triaged emergency
(false negative), any crash on the core flow, an EMERGENCY result blocked by the
paywall, a disclaimer not shown, or any data-isolation/auth (RLS) breach. **Zero P0 is
non-negotiable** — safety outranks the launch date.

Also confirm the roadmap validation targets: **analysis P95 < 10s on 4G**, and **no P0
bugs** across the cohort (check Sentry + PostHog funnels).

## 5. Pre-submission verification (automatable)

```bash
./scripts/verify-phase-2.3.sh      # metadata exist, keyword length, NO "diagnosis" in visible copy
./scripts/verify-disclaimers.sh    # disclaimers are API-injected (not UI-removable)
./scripts/verify-phase-2.2.sh      # legal gate artifacts still intact
```
All three must be green before you submit.

## 6. Submit to the stores (review, not release)

- **iOS:** App Store Connect → fill in the listing from `ios_app_store.md` (title,
  subtitle, keywords, description, screenshots in order). **Paste the App Store Review
  Notes verbatim** — they frame PawDoc as an information/triage tool and pre-empt the
  health-app rejection. Fill the reviewer demo account. Attach the build. Submit.
- **Android:** Play Console → fill the listing from `google_play.md`, complete the
  **Data safety** form and the **content-rating** (IARC) questionnaire, then promote the
  build to **production** review **without** rolling out (staged rollout at 0% until the
  gate clears).

### Expect rejection churn
Apple health-app review takes 2–3 weeks and often needs 2–3 rounds. **Never add
"diagnose/diagnosis/treat/cure" to resolve a rejection** — instead lean harder on the
review notes (information/triage framing, disclaimers, emergencies never paywalled,
in-app deletion per 5.1.1(v)). Keep a log of each rejection reason + response.

## 7. 🚫 The launch gate — DO NOT release to public until this clears

Before tapping **"Release this version"** (iOS) or setting the Play rollout above 0%,
**every** box must be true:

- [ ] Legal gate **fully green**: [`18-legal-and-launch-gate.md`](18-legal-and-launch-gate.md)
      §1 — E&O insurance bound, attorney-reviewed ToS + Privacy **live** at
      `/terms` and `/privacy`, veterinary practice-law review done (CR #24), retention
      policy decided (CR #9).
- [ ] Both stores have **approved** the build (no open P0 rejection).
- [ ] Beta gate cleared: **mean rating ≥ 4.0**, **zero open P0 bugs**.
- [ ] `verify-phase-2.3.sh`, `verify-disclaimers.sh`, `verify-phase-2.2.sh` all green.

If any box is unchecked, the app stays in beta / approved-but-unreleased. **Do not
release to ship faster — the false-negative risk and the legal exposure are the whole
reason this gate exists.**

## 8. Go live (only once §7 is fully checked)

1. **iOS:** App Store Connect → Release this version (or phased release over 7 days —
   recommended).
2. **Android:** Play Console → raise the production rollout (start at **10–20%**, watch,
   then ramp to 100%).
3. **Watch for the first 24–48h:** Sentry crash-free rate, PostHog funnel (analysis
   completion, paywall), latency P95, and any 1-star reviews mentioning a missed
   emergency — treat the latter as a **P0 incident** immediately.

## 9. Rollback

- **Android:** halt the rollout in Play Console (instant) and/or roll back to the prior
  release; staged rollout is your safety net.
- **iOS:** you cannot un-release a build, so **pause phased release** and expedite a fix
  build. If a safety defect is suspected, flip the AI-service **kill-switch** (degraded/
  conservative mode) server-side while you patch — no app update required.

---

### Cross-references
- Legal/insurance hard gate: [`18-legal-and-launch-gate.md`](18-legal-and-launch-gate.md)
- Signing / TestFlight / Play setup: [`11-fastlane-match.md`](11-fastlane-match.md)
- In-app account deletion (Apple 5.1.1(v), CR #9): [`17-polish-push-deletion.md`](17-polish-push-deletion.md)
- Metadata: [`../store_metadata/ios_app_store.md`](../store_metadata/ios_app_store.md) ·
  [`../store_metadata/google_play.md`](../store_metadata/google_play.md)
