# SUB-PR Report — Phase 6.3.1: Family Sharing UI & Invites (Roadmap Closer)

**Status:** Complete and fully green (ruff + 152 pytest, **86 node** incl. invite helpers, `test-rls.sh` PASS — legacy CR #2 + Family Sharing + family_invites, flutter analyze + 91 tests, shellcheck).
**Branch:** `phase-6.3.1-family-sharing-ui` (from `origin/main` = `d4c9013`, post-6.3 merge)
**Date:** 2026-05-28

This sub-PR ships the frontend for the Phase 6.3 RLS redesign — turning the schema-only family-sharing groundwork into a complete user-facing flow (invite → magic link → deep-link accept) — and closes the solo-founder roadmap.

---

## 1. Files created / modified

**DB:**
```
supabase/migrations/20260528040000_family_invites.sql    family_invites table (token UNIQUE + 48h
                                                          expiry + status enum), inviter-only RLS,
                                                          service-role-only writes,
                                                          count_shared_group_memberships() helper
                                                          (SECURITY DEFINER) for the "already in a
                                                          family" check.
supabase/tests/family_invites.sql                        4 assertions: CHECK rejects junk status,
                                                          RLS leak-test, write lockdown, helper math
                                                          across all 4 fixture users.
scripts/test-rls.sh                              (mod)    Applies the new migration + runs the new test
                                                          alongside CR #2 + family_sharing.
```

**Edge / shared helpers:**
```
supabase/functions/_shared/invites.mjs                   Pure helpers: INVITE_ELIGIBLE_TIERS,
                                                          generateInviteToken (32B base64url),
                                                          normalizeEmail, inviteLink,
                                                          buildInviteEmail (Resend payload).
supabase/functions/_shared/invites.test.mjs              6 unit tests (token uniqueness +
                                                          email/link shape).
supabase/functions/invite-family-member/index.ts         verify_jwt=true; tier check, abuse cap
                                                          (10 pending invites/group), generates +
                                                          stores token, sends via Resend if configured
                                                          else returns the magic link in the body.
supabase/functions/accept-family-invite/index.ts         verify_jwt=true; validates token + expiry,
                                                          blocks "already in a family" via the helper,
                                                          idempotent on retry, adds family_members
                                                          row, marks invite accepted.
supabase/config.toml                            (mod)    Registers both Edge Functions with
                                                          verify_jwt=true.
```

**Flutter (UI + deep link + analytics):**
```
mobile/lib/src/family/family_repository.dart             FamilySummary + FamilyMember +
                                                          mySummary() + sendInvite() + acceptInvite()
                                                          + typed FamilyInviteException.
mobile/lib/src/family/family_settings_screen.dart        Members list + Invite CTA + paywall card
                                                          for non-eligible tiers.
mobile/lib/src/family/invite_family_member_screen.dart   Email field + Send + Copy/Share fallback
                                                          + analytics on success.
mobile/lib/src/family/accept_family_invite_screen.dart   Deep-link landing: preview household,
                                                          "Join" or "Not now", analytics on success.
mobile/lib/src/family/pending_invite_prefs.dart          SharedPreferences capture/pop so the token
                                                          survives the sign-in detour for cold-launch
                                                          deep links (mirrors ReferralPrefs).
mobile/lib/src/router/app_router.dart           (mod)    +/family route, +/invite/:token route, +
                                                          deep-link survival logic in the redirect.
mobile/lib/src/home/home_screen.dart            (mod)    +"Family sharing" menu entry.
mobile/lib/src/analytics/analytics.dart         (mod)    +familyInviteSent +familyInviteAccepted.
```

**Docs / verifier:**
```
ENVIRONMENT_VARS.md                              (mod)   +RESEND_API_KEY + RESEND_FROM +
                                                         INVITE_LINK_BASE_URL + Phase 6.3.1 note.
scripts/verify-phase-6.3.1.sh                            Phase verifier (incl. running test-rls.sh).
sub-pr-report/SUBPR_PHASE_6.3.1.md                       This report.
```

## 2. Schema / logic for securely handling pending invites

The `family_invites` table is **service-role-write-only** and **inviter-read-only**, with a 48-hour expiry and a non-guessable token:

```sql
create table public.family_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.family_groups (id) on delete cascade,
  invited_by_user_id uuid not null references public.users (id) on delete cascade,
  invited_email text,                                       -- lowercased, optional for share-link flow
  token text not null unique,                               -- 32 random bytes → 43-char base64url
  expires_at timestamptz not null default now() + interval '48 hours',
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'expired', 'revoked')),
  accepted_by_user_id uuid references public.users (id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz default now()
);

-- RLS — only the inviter sees their own rows.
alter table public.family_invites enable row level security;
create policy family_invites_select_by_inviter on public.family_invites
  for select using ((select auth.uid()) = invited_by_user_id);
revoke insert, update, delete on public.family_invites from anon, authenticated;
grant insert, update, delete on public.family_invites to service_role;
```

**Token entropy:** `generateInviteToken()` uses `crypto.getRandomValues(new Uint8Array(32))` → base64url, no padding → 43 characters. 256 bits of entropy; brute-forcing a valid pending token is infeasible.

**Already-in-a-family check** uses a new `SECURITY DEFINER` helper so it can count memberships across groups the calling user isn't a direct member of:

```sql
create or replace function public.count_shared_group_memberships(check_user_id uuid)
returns integer
language sql stable security definer set search_path = public
as $$
  select coalesce(count(*), 0)::int
  from public.family_members fm
  where fm.user_id = check_user_id
    and (
      select count(*) from public.family_members fm2 where fm2.group_id = fm.group_id
    ) > 1;
$$;
```

A user only in their solo group (size 1) returns 0; any membership in a >1-member group returns ≥1. The accept Edge rejects with `already_in_family` when this is non-zero — the MVP-safe rule from the task brief.

**The /invite-family-member Edge Function** enforces these safety rules **server-side** (not just in the UI):

1. **Tier gate** — caller must have `subscription_status ∈ {family, b2b_lite}`. Returns HTTP 402 with `tier_not_eligible` otherwise. Premium / Free / Trial are deliberately excluded — Family Sharing is the Family-plan upsell.
2. **Abuse cap** — at most 10 outstanding pending invites per group (returns HTTP 429 `too_many_pending_invites`).
3. **Resend optional** — if `RESEND_API_KEY` is configured, the magic link is emailed; if not, the link is logged + returned in the JSON body for the "copy link" fallback UX. The endpoint never fails on a send error.

**The /accept-family-invite Edge Function** validates the full lifecycle:

| Outcome | HTTP | Body code |
|---------|------|-----------|
| Token unknown | 404 | `invite_not_found` |
| Token expired (also marks the row `expired`) | 410 | `invite_expired` |
| Token already used by someone else | 409 | `invite_already_used` |
| Caller already in a shared family (helper > 0) | 409 | `already_in_family` |
| Caller is the inviter | 400 | `cannot_invite_self` |
| Caller already accepted the same invite (idempotent retry) | 200 | `already_accepted: true` |
| Success | 200 | `{ group_id, group_name }` |

The 23505 `unique_violation` on `family_members` is treated as a no-op so a racing double-tap is still safe; the invite row is then flipped to `accepted` and the user gets routed to home with their newly-shared pets visible.

**RLS regression-tested** in `family_invites.sql` (loaded by `test-rls.sh`):

- CHECK constraint rejects `'bogus_status'`.
- A SELECTs and finds their own invite; D SELECTs the same and gets 0 rows (no leak).
- Authenticated cannot INSERT (writes are revoked).
- `count_shared_group_memberships` returns `1` for A (Smith family) and B (Smith family), `0` for C and D (solo only).

The result reads **`FAMILY INVITES TESTS PASSED`** alongside the existing `RLS ISOLATION TESTS PASSED` + `FAMILY SHARING RLS TESTS PASSED` — three independent test suites, one harness run.

## 3. How deep-linking is processed in the client to accept the invite

The deep-link URL is `https://pawdoc.app/invite/<token>` (Universal Link / App Link) or `pawdoc://invite/<token>` (custom scheme) — both share the same path inside go_router, `/invite/:token`. The full lifecycle of a successful accept:

```
1. Inviter's app calls /invite-family-member → token + magic link.
2. Invitee receives the link via email OR a shared message.
3. Tap → OS opens PawDoc at /invite/<token>.

4a. If signed in already:
      go_router renders AcceptFamilyInviteScreen → user taps "Join" →
      POST /accept-family-invite → on 200, refresh pets list, render
      success state.

4b. If signed out:
      go_router redirect saves the path to SharedPreferences via
      PendingInvitePrefs.capture(loc), redirects to /sign-in.
      User signs in (Apple / Google / email) → auth state changes →
      go_router re-runs redirect → loc is '/' → pops the pending
      invite → returns '/invite/<token>' → AcceptFamilyInviteScreen
      renders → user taps "Join" → POST → success.
```

The router additions are:

```dart
GoRoute(path: '/family', builder: (_, _) => const FamilySettingsScreen()),
GoRoute(
  path: '/invite/:token',
  builder: (_, state) => AcceptFamilyInviteScreen(
    token: state.pathParameters['token'] ?? '',
  ),
),
```

And the redirect (now `async`) preserves the deep-link target across the sign-in detour:

```dart
redirect: (context, state) async {
  final loggedIn = client.auth.currentSession != null;
  final loc = state.matchedLocation;
  final atSignIn = loc == '/sign-in';
  if (!loggedIn) {
    if (loc.startsWith('/invite/')) {
      await PendingInvitePrefs.capture(loc);
    }
    return atSignIn ? null : '/sign-in';
  }
  if (atSignIn || loc == '/') {
    final pending = await PendingInvitePrefs.pop();
    if (pending != null) return pending;
  }
  if (atSignIn) return '/';
  return null;
},
```

This mirrors how `ReferralPrefs` was used in Phase 3.3 — same shape, same persistence, same survival semantics. The `PendingInvitePrefs.pop()` is a one-shot read (it clears the key immediately), so a token can't be silently reused on a later cold start.

**Founder-side platform config (MANUAL):**
- **iOS** — Universal Links: add `applinks:pawdoc.app` to the Associated Domains entitlement; host the AASA file at `https://pawdoc.app/.well-known/apple-app-site-association` declaring the `/invite/*` path.
- **Android** — App Links: add an `<intent-filter>` for `android:scheme="pawdoc"` (custom scheme) **and** declare the `pawdoc.app` host with `android:autoVerify="true"` so the OS resolves `https://pawdoc.app/invite/*` directly into the app.

## 4. Project Wrap-Up — the PawDoc Solo Founder Roadmap is officially COMPLETE

What landed across the entire execution:

**Phase 0 — Foundations:** Doppler-backed secret hygiene, gitleaks CI, AI-service skeleton, Supabase project structure.

**Phase 1 — MVP:** initial schema (with CR #2 functional RLS), auth (Apple + Google + Email), photo capture + R2 short-lived presigned URLs, Tier-2 → Tier-3 AI pipeline with **hardcoded EMERGENCY override (pre-AI)**, **cross-verification of EMERGENCY**, confidence floor, kill-switch + degraded fallback, free-tier counter, RevenueCat paywall.

**Phase 2 — Production polish:** native splash + launcher icons, runbooks (00–27), legal docs (drafted, awaiting attorney + E&O insurance), beta + store submission.

**Phase 3 — Retention + Engagement:** multi-pet + health history timeline (RLS-scoped); video analysis (pinned model, P95 < 15s) + semantic cache (same-user, same-species, ≥0.90 cosine, text-only); referral system with fraud controls (transaction-protected RPC, one-claim-per-lifetime, +3 bonus analyses); reminders + re-engagement push (Vault-backed CRON_SECRET, 30-day spam guard); Google Places vet finder (key-hiding Edge proxy) + Markdown export.

**Phase 4 — Experimentation:** PostHog + analysis_feedback (CR #2-applied RLS via parent analysis); 72h follow-up; onboarding + paywall A/B (EMERGENCY-trust SACRED, fail-safe to control); web presence (Next.js static export on Cloudflare Pages, one launch blog post).

**Phase 5 — Expansion:** exotic species + species-specific override (rabbit / guinea-pig / bird / reptile, cross-language sync); web symptom checker (Turnstile + Upstash 3/IP/24h rate limit, fail-closed); **weekly AI Health Journal** with anti-hallucination prompt + chunked-concurrency cron under 60s; **localized emergency keywords (EN + DE, CR #11 closed)** + Flutter i18n infra + embedded telehealth CTA + **B2B-Lite ($19.99/mo sitter tier)**.

**Phase 6 — V2 revenue optimization:**
- 6.1 **Personalization engine** with **two ephemeral Anthropic prompt-cache breakpoints** + **CR #2-eval golden-set safety gate (0 FN on EMERGENCY)**.
- 6.2 **Outcome feedback loop** with FP/FN/TP/TN SQL views (admin-only) + **PII-strip dataset export pipeline** (three defenses: SELECT allowlist + Python allowlist + `assert_no_pii` guard).
- 6.3 **Family-sharing RLS redesign** via SECURITY DEFINER helpers that break recursion, **$4.99 PDF Health Report** with zero server persistence, and the pet-insurance affiliate CTA.
- 6.3.1 **(this sub-PR)** — Family Sharing UI + invite/accept Edge Functions + deep-link survival.

What's deferred to a second engineer (per the roadmap itself):
- **Phase 7 — Infrastructure & B2B API.**
- **Phase 8 — Proprietary AI (on-device + fine-tuned models).**

The seeds for V3 already exist: every analysis carries an outcome label that the Phase 6.2 pipeline ships as JSONL, ready for fine-tuning when a model engineer joins.

## 5. Tests executed & results

| Test | Result |
|------|--------|
| `ruff check .` | **clean** |
| `pytest -q` | **152 pass** (unchanged — 6.3.1 is SQL + Deno + Flutter) |
| `node --test _shared/*.mjs` | **86 pass** (+6 invites helpers) |
| `./scripts/test-rls.sh` (Docker) | **PASS** — CR #2 + family_sharing + **family_invites** |
| `flutter analyze` | **No issues found** |
| `flutter test` | **91 pass** |
| `./scripts/run-eval.py` (6.1 safety gate) | **exit 0** — 12/12 PASS, FN-on-EMERGENCY=0 |
| `./scripts/verify-phase-6.3.1.sh` | **exit 0** — 47 PASS + 4 MANUAL |
| `shellcheck` (verifier + harness) | **clean** |

## 6. MANUAL (founder)

- `supabase db push` — applies the `family_invites` migration + the `count_shared_group_memberships` helper.
- `supabase secrets set RESEND_API_KEY=… RESEND_FROM='PawDoc <noreply@pawdoc.app>'` on the `invite-family-member` Edge Function. Empty key is OK — the magic link is returned in the response body for the in-app "copy link" UX.
- **iOS — Universal Links:** add `applinks:pawdoc.app` to the Associated Domains entitlement; host the AASA file at `https://pawdoc.app/.well-known/apple-app-site-association` declaring `/invite/*`.
- **Android — App Links:** add an `<intent-filter>` for `android:scheme="pawdoc"` + verify `pawdoc.app` via Digital Asset Links so `https://pawdoc.app/invite/*` resolves to the app.
- **(Optional)** Schedule a tiny Postgres cron to flip `pending → expired` once past `expires_at` — purely cosmetic; the accept Edge already rejects expired tokens.

## 7. Git branch / commit / push

- Branch: `phase-6.3.1-family-sharing-ui`
- Implementation commit (deliverables): `baedd0632c9c9bf9c3a4d52841f1b4ec9ac0b496`
- Push: pushed to `origin/phase-6.3.1-family-sharing-ui`; open PR at https://github.com/emredogan-cloud/PawDoc/pull/new/phase-6.3.1-family-sharing-ui

## 8. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| family_invites table (token + 48h expiry + status) | ✅ DONE | migration; pg test |
| RLS: inviter-only SELECT, service-role writes | ✅ DONE | policy + pg test (no-leak) |
| /invite-family-member with server-side tier check | ✅ DONE | INVITE_ELIGIBLE_TIERS guard |
| /accept-family-invite with already-in-family block | ✅ DONE | count_shared_group_memberships helper |
| 48-hour expiry enforced server-side | ✅ DONE | migration default + expiry check in accept |
| Secure token (256 bits, URL-safe) | ✅ DONE | generateInviteToken + unit tests |
| FamilySettingsScreen + tier gate + paywall card | ✅ DONE | family_invite_paywall_card key |
| InviteFamilyMemberScreen + email + copy/share | ✅ DONE | invite_family_member_screen.dart |
| AcceptFamilyInviteScreen + deep link | ✅ DONE | /invite/:token route |
| Deep link survives the sign-in detour | ✅ DONE | PendingInvitePrefs |
| Analytics: family_invite_sent + family_invite_accepted | ✅ DONE | Analytics class |
| Founder-side platform deep-link config + Resend key | ⏳ MANUAL | §6 |

🐾 **PawDoc Solo Founder Roadmap — COMPLETE.** Stopping for final approval.
