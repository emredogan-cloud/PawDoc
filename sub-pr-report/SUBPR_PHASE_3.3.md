# SUB-PR Report — Phase 3.3: Referral System, Rewards & Fraud Controls

**Status:** Complete and fully green (node, referral pg fraud-control test, ruff/pytest, flutter analyze/test, shellcheck). Transactional claim RPC + DB-enforced fraud rules + client-write lockdowns + claim UI.
**Branch:** `phase-3.3-referrals-fraud` (from `origin/main` = `458c71a`, contains 0.1→3.2)
**Date:** 2026-05-27
**Scope note:** Roadmap Phase 3.3 is broader (engagement + notifications + referral). This sub-PR delivers the **referral / rewards / fraud** slice you specified; the notification/cron items remain for a later sub-PR.

---

## 1. Files created / modified

**Created**
```
supabase/migrations/20260527030000_referrals.sql   columns + claim_referral RPC + trigger + lockdowns
supabase/tests/referral.sql                         fraud-control DB test (success/self/double/invalid + lockdowns)
scripts/test-referral.sh                            ephemeral pgvector harness for the above
supabase/functions/claim-referral/index.ts          authenticated Edge Function → claim_referral RPC
supabase/functions/_shared/referral.mjs (+test)     status→{ok,status,message} mapper (single source) + tests
mobile/lib/src/referral/referral_service.dart        invokes claim-referral; typed ReferralClaimResult
mobile/test/referral_test.dart                       referralCodeFromUid + result-mapping unit tests
scripts/verify-phase-3.3.sh                          phase verifier (structural + all batteries)
sub-pr-report/SUBPR_PHASE_3.3.md                     this report
```
**Modified**
```
supabase/functions/_shared/free_tier.mjs (+test)    bonus pool: monthly first, then one-time bonus credits
supabase/functions/analyze/index.ts                 select + pass + persist bonus_analyses
supabase/functions/_shared/... config.toml          [functions.claim-referral] verify_jwt = true
supabase/tests/_local_shim.sql                       baseline default privileges (Supabase-fidelity for the test)
mobile/lib/src/analytics/analytics.dart              referral_code_submitted / referral_success / referral_fraud_prevented
mobile/lib/src/referral/referral_screen.dart         "Got a code?" claim field + loading + toasts (prefilled from deep link)
```
**No new env vars** — `claim-referral` reuses `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY`.

**Reward (MVP):** `claim_referral` grants **+3 bonus analyses to BOTH** the referrer and the referee (`users.bonus_analyses`). The free-tier logic spends the monthly allowance first, then consumes the bonus as a **one-time pool** (so +3 is 3 extra checks total, not +3 every month). A "+1 month premium" variant would need the RevenueCat **server** API — deferred/MANUAL.

## 2. How race conditions & double-claiming are prevented (RPC + constraints)

The entire claim is one PL/pgSQL function, `claim_referral(claimer_id, code)` — i.e. **one transaction** — that does, in order:

1. **`SELECT referred_by_user_id … FROM users WHERE id = claimer_id FOR UPDATE`** — takes a **row lock** on the claimer. Two concurrent claims (rapid double-tap, two requests) **serialize** here: the first proceeds and sets the claim; the second blocks, then reads `referred_by_user_id` already set and returns `already_claimed`. This is the primary **race guard** — no reliance on sequential client calls.
2. **One-claim-per-lifetime:** if `referred_by_user_id IS NOT NULL` → `already_claimed` (no writes).
3. **No self-referral:** if the resolved referrer = `claimer_id` → `self_referral` (no writes).
4. **Invalid code:** code not found in `users.referral_code` → `invalid_code` (no writes).
5. **Atomic grant:** set the claimer's `referred_by_user_id` + `bonus_analyses += 3`, the referrer's `bonus_analyses += 3`, and insert the `referrals` row — all in the same transaction (all-or-nothing).
6. **Defense-in-depth constraint:** `referrals.referred_user_id` is **UNIQUE**, so even if two transactions somehow raced past the row lock, the second `INSERT` raises `unique_violation`, which the function catches and returns `already_claimed` (the transaction's partial writes roll back). Two independent mechanisms (row lock + unique constraint) both prevent a double reward.

**Lockdowns (the strict rule — nothing reward-related is client-writable):**
- `claim_referral` is `REVOKE`d from `public`/`anon`/`authenticated` and `GRANT`ed to `service_role` only → a user can't call it directly via PostgREST with an arbitrary `claimer_id`. The Edge Function passes the **JWT-derived** `user.id` as `claimer_id`.
- `referrals`: `REVOKE INSERT/UPDATE/DELETE` from `anon`/`authenticated` → clients can read their own (RLS) but never write.
- `users`: `REVOKE UPDATE` from clients, then `GRANT UPDATE (one_signal_player_id)` back — so `bonus_analyses`, `referred_by_user_id`, `referral_code`, `subscription_status`, and `free_analyses_used_this_month` are **server-only**. (This also closes a **pre-existing** hole where a user could PATCH their own `subscription_status='premium'` or zero the free counter via the anon key — surfaced + fixed here as security hardening, CR #14.)

All of the above are asserted by `supabase/tests/referral.sql` (run via `./scripts/test-referral.sh`): reward-once on success, blocked self/double/invalid, and the three lockdowns via `has_*_privilege`.

## 3. How to locally test a successful referral between two accounts

**A. Headless, no infra (already automated):**
```bash
./scripts/test-referral.sh
```
Spins an ephemeral pgvector Postgres, applies the migrations, and runs the full two-account scenario (user B claims user A's code → both get +3, B marked referred), plus the self/double/invalid and lockdown cases. Green = the flow works end-to-end at the DB level.

**B. Live local Supabase (full path through the Edge Function):**
```bash
supabase start                       # local stack; migrations apply automatically
# 1) Create two users (sign up twice in the app, or via the dashboard/auth admin).
#    Get each user's code from the app's "Refer a friend" screen, or:
#    select id, email, referral_code from public.users;     -- A_CODE = user A's code
# 2) Sign in as user B in the app → "Refer a friend" → enter A_CODE → "Claim reward".
#    (Or call the function directly with B's access token:)
curl -i "$SUPABASE_URL/functions/v1/claim-referral" \
  -H "Authorization: Bearer <USER_B_JWT>" \
  -H "content-type: application/json" \
  -d '{"code":"<A_CODE>"}'
# Expect: {"ok":true,"status":"success","message":"Reward claimed! ..."}
# 3) Verify the grant:
#    select id, bonus_analyses, referred_by_user_id from public.users
#    where id in ('<A>','<B>');     -- both bonus_analyses +3; B.referred_by = A
# 4) Re-submit the same code as B  -> {"ok":false,"status":"already_claimed",...}
#    Submit B's OWN code as B       -> {"ok":false,"status":"self_referral",...}
```
The app shows a success toast ("Reward claimed!") or the matching error, and refreshes the bonus balance; analytics fire `referral_code_submitted` → `referral_success` / `referral_fraud_prevented`.

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `node --test _shared/*.mjs` | **25 pass** (+5 referral mapping, +3 bonus pool) |
| `./scripts/test-referral.sh` (Docker pgvector) | **PASS** — reward-once, self/double/invalid blocked, 3 lockdowns verified |
| `./scripts/test-rls.sh` + `./scripts/test-semantic-cache.sh` | **PASS** (no regression from the shim change) |
| `ruff` + `pytest` (ai-service) | **clean / 56 pass** (unaffected) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **53 pass** (+4 referral) |
| `./scripts/verify-phase-3.3.sh` | **exit 0** — all structural + batteries green; 3 MANUAL |
| `shellcheck` (new scripts) | **clean** |

## 5. Decisions surfaced (not silently applied)

- **`users` column lockdown extends beyond referrals.** Protecting `bonus_analyses` required also revoking client UPDATE on the row; I scoped the re-grant to the one column the client legitimately writes (`one_signal_player_id`). This **also** closes a pre-existing privilege-escalation hole (self-granting premium / resetting the free counter). Flagged because it changes the write posture of columns from earlier phases — verified safe (the only client write to `users` today is OneSignal's player id) and asserted in the pg test.
- **Reward = +3 bonus analyses (both sides)**, as a one-time pool. The "+1 month premium" alternative needs the RevenueCat server API (no client-trusted entitlement grants) — deferred/MANUAL.
- **Referral codes keep the existing 1.4 scheme** (first 8 hex of the UID). At tens of thousands of users this 8-char space can collide; the `UNIQUE` constraint + a length-extending insert trigger keep signup safe, and a follow-up could move to a generated code the client fetches. Flagged, not silently changed.

## 6. Git branch / commit / push

- Branch: `phase-3.3-referrals-fraud`
- Implementation commit (deliverables): `52645afed94174315a9910b3fa3ffc757c4732ee`
- Push: pushed to `origin/phase-3.3-referrals-fraud`; open PR at https://github.com/emredogan-cloud/PawDoc/pull/new/phase-3.3-referrals-fraud

## 7. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| `/claim-referral` Edge Function (look up code → referrer → eligibility) | ✅ DONE | `claim-referral/index.ts` + RPC |
| One claim per lifetime; no self-referral | ✅ DONE | RPC guards; pg test |
| Race-condition prevention via transactional RPC | ✅ DONE | `FOR UPDATE` lock + UNIQUE `referred_user_id`; pg test |
| Reward to referrer + referee | ✅ DONE | `bonus_analyses += 3` both; free-tier honors it; pg + node tests |
| Client UI: code field, loading, success/error toasts | ✅ DONE | `referral_screen.dart` claim card |
| Analytics: submitted / success / fraud_prevented | ✅ DONE | `analytics.dart` + screen wiring |
| referrals + rewards NOT client-writable | ✅ DONE | lockdowns; pg `has_*_privilege` asserts |
| Two-account flow on a live project | ⏳ MANUAL | recipe in §3 (headless proof automated) |

**Verified now:** the full fraud-control + reward flow is proven at the database level, the client write surface is locked down (and a pre-existing escalation hole closed), and analytics + UI are wired. Stopping for approval before the next sub-PR (Phase 3.3 notifications, or as you direct).
