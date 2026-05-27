# SUB-PR Report — Phase 4.1: Experimentation Infrastructure

**Status:** Complete and fully green (node, follow-up + RLS pg tests, ruff/pytest, flutter analyze/test, shellcheck). Resilient PostHog feature flags + deterministic bucketing, in-app thumbs feedback, and the RLS-scoped 72h follow-up.
**Branch:** `phase-4.1-experimentation` (from `origin/main` = `71bb6a1`, contains 0.1→3.4)
**Date:** 2026-05-27

---

## 1. Files created / modified

**Created**
```
supabase/migrations/20260527050000_followup.sql   pending_followup_analyses() RPC (eligibility)
supabase/tests/followup.sql + scripts/test-followup.sh  eligibility pg test (RLS-scoped, as user A)
mobile/lib/src/experiments/feature_flags.dart      resilient PostHog flag wrapper + keys + providers
mobile/lib/src/feedback/analysis_feedback_repository.dart  insert + pure feedbackColumns()
mobile/lib/src/feedback/result_feedback_widget.dart thumbs up/down (+ optional comment) on results
mobile/lib/src/feedback/pending_followup.dart       pendingFollowupProvider (calls the RPC)
mobile/lib/src/feedback/followup_prefs.dart         "Not now" snooze
mobile/lib/src/feedback/followup_banner.dart        home banner → outcome → analysis_feedback
mobile/test/feature_flags_test.dart, feedback_test.dart  unit tests
scripts/verify-phase-4.1.sh                          phase verifier
sub-pr-report/SUBPR_PHASE_4.1.md                     this report
```
**Modified**
```
supabase/tests/rls_isolation.sql              + analysis_feedback INSERT controls (own ok / B's blocked)
mobile/lib/main.dart                          Posthog().identify(uid) on auth (deterministic bucketing)
mobile/lib/src/analytics/analytics.dart       feedback_submitted
mobile/lib/src/analysis/analysis_runner.dart  thread analysisId → ResultScreen
mobile/lib/src/analysis/result_screen.dart    analysisId param + renders the feedback widget
mobile/lib/src/home/home_screen.dart          FollowUpBanner at the top (self-hides)
```
**No new secrets / env vars** — PostHog is already configured (Phase 1.2); flags + identify use the existing setup.

## 2. `analysis_feedback` is protected by RLS — and writable by the client (proof)

- The RLS was **already added by CR #2 in Phase 1.1** (`analysis_feedback_owner`, both `USING` and `WITH CHECK`). The table has **no `user_id` column** — ownership is derived from the **parent analysis**: `EXISTS(analyses a WHERE a.id = analysis_feedback.analysis_id AND a.user_id = auth.uid())`. This is the "equivalent via the analysis relationship" form your rule allows. I **preserved** it (no change) and added **proof** rather than re-deriving it.
- `rls_isolation.sql` (run via `test-rls.sh`, **green**) now asserts, acting as user A:
  - **A CAN** insert feedback for **its own** analysis (`a1a1…`) → the row persists (the legit client write works).
  - **A CANNOT** insert feedback for **B's** analysis (`b1b1…`) → the `WITH CHECK` raises `insufficient_privilege` (blocked).
- So the client (the thumbs widget + the follow-up banner) submits `{analysis_id, rating|outcome, comment}` with **no `user_id`**; RLS validates ownership through the analysis. Verified at the DB level.

## 3. How the 72h follow-up determines eligible analyses

A single SQL function, `pending_followup_analyses()` (migration `…050000`):
```sql
select a.id, a.pet_id, a.triage_level, a.created_at
from public.analyses a
where a.created_at < now() - interval '72 hours'           -- older than 72h
  and not exists (                                          -- not yet reviewed
    select 1 from public.analysis_feedback f where f.analysis_id = a.id)
order by a.created_at desc
limit 5;
```
- It is **`SECURITY INVOKER`**, so when the authenticated app calls it, **RLS is enforced with the caller's `auth.uid()`**: the `analyses` scan returns only the user's own analyses, and the `NOT EXISTS` sees only the user's own feedback. No cross-user leakage; "no feedback" is correctly per-user.
- **Fires once per analysis:** once *any* feedback row exists for an analysis (from the result thumbs OR a banner outcome), it drops out of the result set. The client banner additionally **snoozes 24h** on "Not now" so it doesn't nag every launch.
- Proven by `test-followup.sh` (**green**), acting as authenticated user A: returns **exactly** the old + no-feedback analysis, and excludes the recent one (<72h), the one that already has feedback, and **B's** analysis (cross-user).

## 4. Feature flags — resilient + deterministic

- `FeatureFlags.isEnabled(key, {defaultValue = false})` wraps `Posthog().isFeatureEnabled` in a `try/catch` and **returns the control default on any error** (PostHog not configured, offline, SDK throw) — never throws, never blocks the UI. Unit-tested (a throwing source → default; explicit default honored).
- **Deterministic + stable bucketing:** `main.dart` now calls `Posthog().identify(userId: <supabase uid>)` on auth, so a given user always lands in the same variant across sessions/devices. `FeatureFlagKeys.paywallTiming` is defined as the first intended A/B; reading it is infrastructure only here (the actual paywall-timing experiment lands in 4.2 and must not alter the EMERGENCY/trust rules).

## 5. Tests executed & results

| Test | Result |
|------|--------|
| `./scripts/test-followup.sh` (Docker) | **PASS** — eligibility: >72h + no-feedback, RLS-scoped per user |
| `./scripts/test-rls.sh` (Docker) | **PASS** — incl. new `analysis_feedback` insert controls |
| `node --test _shared/*.mjs` | **36 pass** (unchanged — no new shared logic) |
| `ruff` + `pytest` (ai-service) | **clean / 56 pass** (unaffected) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **70 pass** (+6: feature-flag fallback, feedback payload) |
| `./scripts/verify-phase-4.1.sh` | **exit 0** — all structural + batteries green; 3 MANUAL |
| `shellcheck` (new scripts) | **clean** |

## 6. MANUAL (founder)

- Create the PostHog feature flag(s) (e.g. `paywall-timing`) + the A/B dashboards in the PostHog UI (the client reads them; assignment is server-side in PostHog).
- On device: thumbs up/down on a result persists to `analysis_feedback`; the 72h banner appears for an eligible analysis and fires once; verify variant stability across sessions.

## 7. Git branch / commit / push

- Branch: `phase-4.1-experimentation`
- Implementation commit (deliverables): `<filled post-commit>`
- Push: `<filled post-push>`

## 8. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| PostHog feature flags, deterministic + safe-loading | ✅ DONE | `feature_flags.dart` + identify(uid); unit test |
| Resilient default-to-control on failure/offline | ✅ DONE | `isEnabled` try/catch; unit test |
| Thumbs up/down + optional comment on results | ✅ DONE | `result_feedback_widget.dart` |
| Persist to `analysis_feedback` | ✅ DONE | repo insert; RLS proof |
| `analysis_feedback` RLS (own only) | ✅ DONE | CR #2 policy + rls_isolation controls (test-rls green) |
| 72h "was this helpful?" prompt | ✅ DONE | RPC + banner; fires once per analysis |
| A/B dashboards | ⏳ MANUAL | PostHog UI |
| On-device feedback/banner round-trip | ⏳ MANUAL | §6 |

**Verified now:** feedback is RLS-protected *and* client-writable (DB-proven), the 72h eligibility query is RLS-scoped and fires once per analysis (DB-proven), and feature flags fail safe to control — analyzer + 70 tests + node + ruff/pytest all green. Stopping for approval.
