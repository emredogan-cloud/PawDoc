# PawDoc — Final Production Report

**Date:** 2026-07-18 · **Branch:** `feat/release-candidate` (PR #81) · CI green.
**Companion reports:** `PAWDOC_STORE_REVIEW_FINAL.md` · `PAWDOC_URUN_DOKUMANI_TR.md` (Turkish) · `PAWDOC_PRELAUNCH_CHECKLIST.md`.

> **Bottom line:** Engineering, infrastructure, and the AI pipeline are **production-synchronized and verified working end-to-end** on real hardware. **One architecture reality dominates the launch picture: there is a single shared Supabase project for dev and "prod"** — no isolation, and it currently holds test data. That is the top founder decision before a real launch. Store submission is **YES WITH CONDITIONS for Google Play, NO/NOT-YET for Apple** (iOS never built or run on hardware). Full verdict at the end.

---

## 1. Production synchronization

### 1.1 The environment reality (most important finding)
The `prd` and `dev` Doppler configs resolve to the **same Supabase project** (`zbxrvfunaylkscgvsllm.supabase.co`) — verified by a byte-identical `SUPABASE_URL` compare. There is **no separate production Supabase project**; `stg` is empty. The Fly AI app (`pawdoc-ai`) is likewise a single shared app. R2 has separate `dev`/`prod` bucket names but one account.

**Consequence:** "synchronizing production" is already accomplished — the project I aligned this cycle **is** what the `prd` config points at. But it also means **dev testing and production share one database**, and that database currently contains **5 test accounts** (e.g. `rcqa.device@pawdoc-test.com` + pet "Rex") created during validation. This is the #1 launch decision (see §5 and the checklist).

### 1.2 Components — deployed & verified
| Component | State | Evidence |
|---|---|---|
| **Supabase schema** | Rebuilt to the repo's **26 migrations** | verified: `analyses.action` present; `triage_level`/`referrals`/`family_members` gone; `accepted_terms_at` present; signup trigger live; history=26 |
| **Edge Functions** | Exactly the **6 repo functions** deployed; **7 obsolete deleted** | `functions list` = analyze, analyze-anonymous, delete-account, generate-pdf-report, generate-upload-url, revenuecat-webhook |
| **Edge secrets** | AI/R2/RevenueCat/Turnstile/Upstash set; **7 legacy vendor secrets removed** | ONESIGNAL/OPENAI/PLACES/RESEND/INVITE unset |
| **AI service (Fly)** | Healthy (`/health` 200), redeployed with the timeout fix | 2 machines started, `fra` |
| **Legal portal (AWS/CloudFront)** | 15 pages live over HTTPS | privacy/terms/subscriptions = 200; HSTS + nosniff |
| **R2 storage** | Buckets + presign function deployed | uploads are a premium/photo path (text checks need no upload) |

### 1.3 Deployments NOT performed (and why)
- **A separate isolated production Supabase project** — does not exist; creating one is a founder infrastructure decision (see checklist). I did **not** fabricate a prod project or point anything new at it.
- **Test-data purge** — the shared "prod" DB holds test accounts. Deleting user rows is a destructive production action **not required by the migration plan**, so per the mission's guardrail I **documented** it rather than executing it. If the founder launches on this same project, purge first; if they create a fresh prod project, it's moot.
- **RevenueCat products / Apple auth secrets** — founder-held credentials; deploying without them is unsafe/incomplete (documented in the checklist).

## 2. Validation performed

- **Full authenticated E2E on a physical Android device** (Redmi, Android 11): sign-in → home → describe symptoms → **real Gemini/Claude analysis** (`CALL_TODAY`, saved to history) → **offline airplane-mode emergency path** with first-aid cards. Screenshotted.
- **AI pipeline correctness, both paths:** a detailed limping-dog input returned a rich `CALL_TODAY` with vet-look-for + what-to-do; a sparse "cat sneezing" input correctly floored to `WATCH_AND_RECHECK` / "not enough information" (confidence-floor, never-fabricate behavior). The **safe-degrade** path is also confirmed reachable.
- **Automated suites (final head):** `flutter analyze` clean · **222 Flutter** · **159 pytest** · **59 node** · ruff · disclaimers · overclaims · shellcheck — all green; **CI green** on `aabba9c`. The full-migration RLS + deletion-cascade suite is a required CI job; golden set holds 0 false negatives on `GET_HELP_NOW`.

## 3. Final engineering status
- **Feature-complete** per the evolution baseline (#80) + this RC. No agent-executable engineering blocker remains for the Android path.
- Bugs fixed this cycle include a **CRITICAL production AI bug** (provider timeouts made every analysis silently degrade — Gemini's 8s deadline was below its API's 10s minimum; fixed to 12s/15s, redeployed, re-verified), the raw-error and destructive-delete UX HIGHs, and a silent GDPR RevenueCat-purge gap.
- PR #81 is MERGEABLE, CI green, founder-review-gated on protected `main` (expected).

## 4. Production readiness (engineering/infra)
- **Engineering: ready.** Code, tests, and CI are green; the app runs correctly on real hardware against the repo-aligned backend.
- **Infrastructure: functional but not launch-isolated.** Everything works, but on a single shared project. For a controlled beta this is acceptable; for a public launch, environment isolation is strongly recommended.

## 5. Launch verdict (engineering/infra view; full store verdict in the combined section)
PawDoc is **engineering- and infrastructure-ready for a controlled Android beta today** on the current shared project (after a test-data purge). It is **not yet ready for Apple** (never built/run on iOS; Apple-auth unprovisioned). A *clean public production launch* is **conditional** on the founder decisions in §1.3 + the checklist — chiefly a decision on production environment isolation, release signing, RevenueCat products, and the legal/vet/E&O sign-offs. See the combined final verdict at the end of `PAWDOC_STORE_REVIEW_FINAL.md` and `PAWDOC_PRELAUNCH_CHECKLIST.md`.
