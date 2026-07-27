# PAWDOC GO-LIVE MASTER PLAN

> **Date:** 2026-06-12 · Built from `PAWDOC_LAUNCH_GAP_ANALYSIS.md` (findings) and `PAWDOC_REMEDIATION_PLAYBOOK.md` (fix recipes — IDs referenced below).
> **Owners:** ENG = agent-executable engineering (one PR per work-package, squash-merge, approval gate per CLAUDE.md) · FND = founder-only (accounts, money, legal, device).

---

## THE PICTURE IN ONE PARAGRAPH

Engineering debt to a launch-grade product is **~2 working weeks** and is fully parallelizable with the true critical path: the **founder's legal/insurance gate (2–4+ weeks, external)**. If F-1 (attorney) and F-2 (E&O) start **today**, engineering finishes inside their shadow, a sideload beta can run within ~1 week, a store-distributed 50-user beta starts the day the legal pages go live, and public submission follows the beta gate. Realistic public launch: **5–8 weeks from today**. Nothing on this timeline is compressible by writing more code — only by starting F-1/F-2 immediately.

```
Week:        1         2         3         4         5         6         7        8
ENG   [ Wave 0 ][ Wave 1 ]      (fix cycle during beta)─────────┐
FND   [F-1 attorney ───────────────][publish legal]                │
      [F-2 E&O quotes ────────][bound]                             │
      [F-4..F-16 console/infra ops]                                │
BETA              [Tier-1 sideload]→[ Wave 3: 50-user store beta ──]→[ Wave 4: submit → review → staged rollout ]
```

---

## WAVE 0 — STOP-THE-BLEEDING CRITICALS

**Objective:** the product actually does what it claims, can't be trivially abused, can't lose data, and tells the founder when it breaks.
**Duration:** 5–7 ENG days · **Dependencies:** none — start immediately · **Owner:** ENG (+½ FND day of consoles)

| Work package (suggested PR grouping) | Playbook IDs |
|---|---|
| PR-1 `fix/ai-multimodal` — attach pixels + media fetcher + payload contract tests + golden images | **A1** |
| PR-2 `fix/analyze-ssrf-and-quota` — server-derived URLs only; emergency-safe quota for photo/video; degraded ≠ credit | **A2, A3, E7** |
| PR-3 `fix/ai-survivability` — provider timeouts, max_retries=0, size/frame caps, fly concurrency, docs off in prod, pins, Gemini max_output_tokens | **A4, E11** |
| PR-4 `fix/client-402-mapping` — FunctionException mapper: quota→paywall, PDF upsell, family errors; client upload/analyze timeouts | **A5, E10, E8d** |
| PR-5 `fix/deletion-cascade` — R2 purge + RC/OneSignal/PostHog deletion + deletion_log | **A6** |
| PR-6 `fix/upload-hardening` — object size/type verification, server EXIF backstop in media fetcher | **E8b/c** |
| PR-7 `ops/observability-min` — ai-service Sentry, edge alerts, server-side degraded events, mobile env/release tags | **D2** |
| PR-8 `ops/drift-and-guards` — sync-secrets script, fly.toml fra, delete auth-webhook, prod-deploy guard script | **D3, D1.2** |
| Local (no PR): chmod 600 secrets, gitignore doppler.json, commit laptop-only docs+fonts | **E15** |
| FND parallel: **start F-1 attorney + F-2 E&O today**; F-3 entity; F-4 domain/email live; F-5 Supabase Pro+PITR+dev project; F-11 spend caps; F-16 FCM; F-17 live photo check after PR-1/2 deploy | F-1..5, 11, 16, 17 |

**Success criteria (gate to Tier-1 beta):**
- A real photo analysis on-device returns a result referencing visible content (F-17 evidence).
- SSRF negative probe rejected; burst smoke keeps `/health` green; degraded analysis costs no credit; free user's 4th check shows upgrade UI.
- Account deletion leaves zero R2 objects (drill evidence).
- Killing a provider key in dev raises two independent alerts within minutes.
- `dig pawdoc.app` resolves; `/privacy` `/terms` serve **interim honest text** (template-derived, clearly dated, attorney-pending) — or beta invite states policies pending; support@ round-trips mail.
- Prod DB: Pro + PITR enabled; dev project exists; restore drill documented.

**→ Tier-1 beta unlocked:** 10–20 friends/family via direct APK. (Store-distributed beta still gated on Wave 2.)

---

## WAVE 1 — RELEASE MECHANICS & PRODUCT COMPLETENESS

**Objective:** a store-grade, truthful, supportable build with working auth/lifecycle flows.
**Duration:** 4–6 ENG days (overlaps Wave 0 tail) · **Dependencies:** F-6 keystore for PR-9; F-7/F-8 accounts for PR-10 validation · **Owner:** ENG + FND consoles

| Work package | Playbook IDs |
|---|---|
| PR-9 `release/android-signing` — keystore wiring, R8 + keeps, CI non-debug-signature assertion, release-build device smoke | **B1** |
| PR-10 `release/fastlane` — per-platform lanes, fixed release.yml, staged-rollout params, rollback docs | **B4** |
| PR-11 `release/store-surface` — launcher icons + labels, permission diet, truthful store metadata + web copy + placeholder CI gate | **B2, B3, B5** |
| PR-12 `feat/auth-lifecycle` — password reset + recovery link, provider matrix fix (Apple iOS-only; Google add-or-disable), OneSignal logout, allowBackup | **E1, E3, E6, C4.6** |
| PR-13 `feat/compliance-ui` — consent gate + analytics toggle, ToS acceptance checkbox + timestamp, paywall Terms/Privacy/auto-renew + restore feedback + cancel handling, bundled fonts, location permissions | **C4, C5, E2** |
| PR-14 `fix/db-hygiene` — CHECK constraints, indexes, security_invoker views, RPC grant revoke, PDF decrement guard, pets WITH CHECK, referral bonus cap (push to dev → prod) | **E14, E12.2, E16.4** |
| PR-15 `feat/ux-batch` — quota pre-gate, symptom min-length fix, calm error copy + Sentry capture, family Upgrade→paywall, RC webhook idempotency | **E16, E12.3, E5.2** |
| PR-16 `ops/ci-sovereignty` — node-tests + deno check + nightly RLS + pinned actions + deploy-gated-on-CI; founder applies required checks (F-12) | **D5** |
| PR-17 `ops/runbooks-support` — runbooks 22–27, in-app Contact support, feedback digest | **D4** |
| Decisions to record in PAST_DECISIONS: l10n scope (**E13** — recommend EN-only), TR keywords (**E4** — required if TR market), family entitlement (**E12.1**), invite email-binding (**E9**) | E4, E9, E12, E13 |
| FND: F-6 keystore, F-7 Play account, F-8 Apple account, F-9 env-vars refresh, F-13 Resend SMTP, F-14 confirmations ON + auth round-trip, F-15 RevenueCat products + key, F-19 tax/payout, F-20 TalkBack + screenshots | F-6..9, 13..16, 19, 20 |

**Success criteria:** release-signed AAB accepted by Play console (internal track) via one git tag; full validation matrix (Playbook PART 3) green; red-PR cannot merge; sandbox purchase + webhook → premium entitlement verified; push received on device; password-reset round-trip works; TalkBack pass logged.

---

## WAVE 2 — LEGAL GATE & STORE READINESS (founder-dominated, runs from day 1)

**Objective:** the external hard gate the project itself defined: real legal docs live, insurance bound, store consoles fully prepared.
**Duration:** calendar 2–4 weeks (attorney/insurer-bound), hands-on ~3 FND days · **Dependencies:** F-1/F-2 started in Wave 0; B5/B6 from Wave 1 · **Owner:** FND (+ENG ½ day publishing pages)

- Attorney deliverables in → fill `docs/legal/*`, publish `/privacy` + `/terms` on pawdoc.app (ENG: web pages + truthified footer); affirmative-acceptance text final (PR-13 already wired the checkbox); retention decision (CR #9) → implement R2 lifecycle rule + policy text; KVKK annex; entity per F-3.
- E&O **bound** with effective date ≤ beta start (store beta = public-ish exposure; insurer may distinguish — ask).
- Store consoles: data-safety + privacy labels from B6 docs; content rating; Health declarations; demo account; reviewer notes (already strong) finalized; screenshots/feature graphic uploaded; Play web deletion URL live.
- CR #24 vet-practice-law output → confirm launch jurisdictions (recommend US+TR-or-EU subset per counsel) → store country list set accordingly.

**Success criteria:** `verify-phase-2.2.sh` manual items all YES with evidence; both store listings pass a dry-run completeness check; insurance certificate on file; PAST_DECISIONS updated (entity, retention, jurisdictions).

---

## WAVE 3 — 50-USER STORE BETA

**Objective:** the roadmap's own beta gate, now real: TestFlight external (after Apple's beta review) + Play closed track.
**Duration:** 2–3 weeks · **Dependencies:** Waves 0–2 complete · **Owner:** FND (recruiting/comms) + ENG (fix cycle)

- Recruit per F-18 (50 testers; pet communities + clinic clients).
- Instrumented watch: PostHog funnel (signup→pet→check→result), degraded-rate alert, Sentry triage each morning, feedback digest.
- Weekly live-config device ritual (the root-cause #3 prevention) — incl. one photo, one video, one emergency, one deletion.
- Fix cycle: P0/P1 within 48 h via the now-working release lanes (staged tracks).

**Success criteria (from the roadmap, unchanged):** ≥30 survey responses · avg rating ≥4.0 · **zero P0** · P95 analysis <10 s on 4G · plus new: degraded-rate <5%, no unhandled Sentry crash affecting >1 user, photo-path verified by ≥10 real photo checks.

---

## WAVE 4 — SUBMISSION, LAUNCH & POST-LAUNCH SAFEGUARDS

**Objective:** store review → controlled public rollout → don't regress.
**Duration:** 1–3 weeks (Apple review cycles dominate; budget 2–3 rounds per runbook 19) · **Owner:** FND submits, ENG on review-feedback standby

- Submit Play first (faster signal), Apple in parallel; respond to reviews <24 h.
- **Staged rollout:** Play 10%→50%→100% over ≥1 week; iOS Phased Release ON; halt criteria pre-written (crash rate >1%, degraded >10%, any safety incident).
- Day-1 watch: uptime, Sentry, degraded-rate, spend dashboards (alert thresholds already live from Wave 0).
- Post-launch backlog (first month): gallery-upload feature (B3's product gap), async service rework before any growth push (the 100k-user wall), TR keyword pack if TR market (E4), vet advisor engagement (F-10), quarterly restore + rotation drills, golden-set expansion with real (consented) beta cases.

**Success criteria:** both stores approved; 100% rollout with crash-free ≥99%; first-week support response <24 h; zero safety-path incidents; spend within forecast ($35–100/mo at this scale).

---

## CRITICAL PATH & WHAT-IFS

- **Critical path = F-1 (attorney) → legal pages → store beta → submission.** Everything else fits inside it. Late F-1 start delays launch day-for-day.
- **If budget forces choices:** the only non-negotiables are Wave 0, B1/B2/B5, F-1 (privacy/ToS at minimum), F-4, F-5, F-7. E&O (F-2) is the project's own stated hard gate — launching without it is an explicit, recorded founder risk decision, not a default.
- **If Apple drags (1.4.1 medical):** launch Android-first publicly (Play approval + the Android-complete codebase support it); keep TestFlight beta running for iOS.
- **Single biggest schedule risk after legal:** first-ever execution of the release lanes (B4) — they have never run end-to-end; do the `v0.9.0-beta1` dry-run tag in Wave 1, not during submission week.

---

## FINAL VERDICT

> ### Can PawDoc launch tomorrow? — **NO.**

**Why (the irreducible four):** (1) photo/video triage doesn't actually analyze images (GAP-A1) — shipping it would be shipping a safety claim that isn't true; (2) there is no store-submittable artifact (debug signing, default icon, broken release path — GAP-B1/B2/B4); (3) the legal gate the project itself defined is fully open (template docs, no insurance, dead domain — GAP-C1/C2/C3); (4) production is unobserved (GAP-D2) and un-backed-up (GAP-D1) — real users' pet-health data with no restore path and no alarm bell.

**What must happen first:** Wave 0 in engineering; F-1 + F-2 + F-4 + F-5 on the founder side — all startable today, all listed step-by-step in the playbook.

**Shortest honest path:** sideload beta in ~1 week (Wave 0) → store beta the day legal pages go live (Waves 1–2, ~2–4 weeks, attorney-bound) → submission after the beta gate (Wave 3) → staged public launch. **≈5–8 weeks end-to-end, dominated by the attorney/insurer/store-review calendar, not by code.**

The encouraging truth this audit also proved: the safety core — the thing that would actually hurt someone if wrong — is the best-engineered part of the product (text-path triage, emergency handling, disclaimers, isolation, fail-closed moderation all verified live or against real Postgres). The work between here and launch is finite, enumerated, and almost entirely about making the rest of the product as honest as its safety pipeline.

*End of master plan.*
