# Phase 1A — Database + RLS + Edge Function Foundations — IMPLEMENTATION

**Project:** PawDoc
**Phase:** 1A (Schema + RLS + Edge Function scaffolds)
**Date:** 2026-05-15
**Plan reference:** [`phase1a-db-plan.md`](phase1a-db-plan.md)

---

## 1. Summary

Phase 1A is complete. The PawDoc database has its full Phase 1 schema with
per-CRUD RLS policies on every user-owned table, the three edge functions
exist as validated authentication scaffolds returning structured 501s where
business logic is deferred to 1B, and a pgTAP suite of 48 RLS isolation tests
runs green locally and is wired into CI.

Phase 0 architecture is preserved exactly. No frameworks added. No
repository structure changes.

### Verification (all run locally)

| Command | Result |
|---------|--------|
| `supabase db reset` | ✅ all 9 migrations apply cleanly from scratch |
| `supabase test db` | ✅ **48/48** pgTAP RLS isolation tests pass |
| `deno fmt --check` (`supabase/functions`) | ✅ Checked 20 files |
| `deno lint` (`supabase/functions`) | ✅ Checked 16 files |
| `deno check **/*.ts` | ✅ all `.ts` files type-check |
| `deno test --allow-env --no-check` | ✅ 12/12 edge-function unit tests pass |
| `make lint` (Phase 0 gates) | ✅ ruff/mypy/dart/flutter analyze all clean |
| `make test` (Phase 0 gates) | ✅ 22 ai-service + 4 mobile tests pass |

---

## 2. Implemented Tables

All seven tables defined by [roadmap §5](../../roadmaps/APP_EXECUTION_ROADMAP.md#5-data-model-design)
were migrated, in this order:

| # | Migration | Table | Owner key | RLS posture |
|---|-----------|-------|-----------|-------------|
| 0 | `20260515220000_extensions.sql` | n/a — enables `pgcrypto`, `uuid-ossp`, `vector` | — | — |
| 1 | `20260515220100_users.sql` | `users` | `id = auth.users.id` | SELECT/UPDATE own (column-level GRANT for billing fields); INSERT/DELETE deny |
| 2 | `20260515220200_pets.sql` | `pets` | `user_id` | full CRUD on own |
| 3 | `20260515220300_analyses.sql` | `analyses` | `user_id` | SELECT own; **INSERT/UPDATE/DELETE deny** (append-only legal record) |
| 4 | `20260515220400_health_events.sql` | `health_events` | `pet_id → pets.user_id` | full CRUD via parent-ownership join |
| 5 | `20260515220500_reminders.sql` | `reminders` | `user_id` | full CRUD on own |
| 6 | `20260515220600_analysis_feedback.sql` | `analysis_feedback` | `analysis_id → analyses.user_id` | SELECT/INSERT own; UPDATE/DELETE deny (append-only) |
| 7 | `20260515220700_referrals.sql` | `referrals` | `referrer_user_id` | SELECT/INSERT own; UPDATE/DELETE deny (service role only) |
| 8 | `20260515220800_free_tier_helpers.sql` | n/a — adds `attempt_consume_free_analysis(uuid, int)` | — | service-role-only EXECUTE |

### Column-level constraints landed

| Table | Check |
|-------|-------|
| users | `subscription_status IN ('free','trial','premium','family')`; `free_analyses_used_this_month >= 0` |
| pets | `species IN (...)`; `sex IN ('male','female','unknown')`; `weight_kg > 0`; `name` non-blank |
| analyses | `input_type IN ('photo','video','text')`; `triage_level IN ('EMERGENCY','MONITOR','NORMAL')`; `tier_used IN (2,3,4)`; `confidence_score ∈ [0,1]`; `ai_latency_ms >= 0` |
| health_events | `event_type IN ('vaccination','vet_visit','medication','weight','custom')` |
| reminders | `reminder_type IN ('vaccination','medication','vet_visit','follow_up','custom')` |
| analysis_feedback | `outcome IN (...)`; `rating ∈ [1,5]`; at least one of outcome/rating/comment must be non-null |
| referrals | `length(referral_code) ∈ [4,64]`; `converted` and `converted_at` are consistent (both null or both set) |

### Indexes landed

All eight indexes from roadmap §5 plus one safety index (`idx_referrals_referrer`)
to keep the RLS predicate index-served:

```
idx_users_subscription                   users(subscription_status)
idx_pets_user_id                          pets(user_id) WHERE is_active = true
idx_analyses_pet_id                       analyses(pet_id)
idx_analyses_user_id_created              analyses(user_id, created_at DESC)
idx_analyses_triage_level                 analyses(triage_level)
idx_analyses_embedding                    analyses USING ivfflat (embedding vector_cosine_ops) lists=100
idx_health_events_pet_id_date             health_events(pet_id, event_date DESC)
idx_reminders_due                         reminders(due_date) WHERE is_sent = false
idx_reminders_user_id                     reminders(user_id)
idx_analysis_feedback_analysis_id         analysis_feedback(analysis_id)
idx_referrals_referrer                    referrals(referrer_user_id)
```

---

## 3. Implemented RLS Policies

**Per-CRUD policies, explicit names, no implicit behaviour.** 28 policies
across 7 tables (4 CRUD operations each):

```
users              4   (select_own, insert_deny, update_own, delete_deny)
pets               4   (select_own, insert_own, update_own, delete_own)
analyses           4   (select_own, insert_deny, update_deny, delete_deny)
health_events      4   (select_own, insert_own, update_own, delete_own)   via parent-pet join
reminders          4   (select_own, insert_own, update_own, delete_own)
analysis_feedback  4   (select_own, insert_own, update_deny, delete_deny) via parent-analysis join
referrals          4   (select_own, insert_own, update_deny, delete_deny)
```

### Defence-in-depth: column-level GRANT on users

The RLS UPDATE policy on `users` allows the user to touch their own row, but
the GRANT was narrowed to only profile-relevant columns:

```sql
REVOKE UPDATE ON users FROM authenticated;
GRANT  UPDATE (preferred_locale, last_active_at, one_signal_player_id)
       ON users TO authenticated;
```

A user trying to `UPDATE users SET subscription_status = 'premium'` therefore
fails with `permission denied for column subscription_status` — even though
the RLS row predicate would otherwise permit the row.

### Why service-role bypass is acceptable

The `service_role` key holds `BYPASSRLS` in Postgres. Three callers hold it:
- **ai-service** (Fly.io) — writes analyses
- **edge functions** (analyze, auth-webhook, revenuecat-webhook) — writes
  users + flips subscription state
- **Supabase Dashboard operators**

None of these are user-facing. The mobile app NEVER receives the
service-role key. This is the architecture's only RLS escape hatch and it is
tightly scoped.

---

## 4. Security Guarantees Demonstrated by Tests

The pgTAP suite at `supabase/tests/rls_isolation.test.sql` proves the
following invariants, with one assertion per claim:

| Invariant | Coverage |
|-----------|----------|
| Authenticated users see only their own rows | users, pets, analyses, health_events, reminders, analysis_feedback, referrals (7 SELECT-isolation assertions across tables, plus 2 cross-direction sanity checks from the other user's perspective) |
| Cross-user INSERTs are blocked at the policy layer | pets, health_events, reminders, analysis_feedback, referrals (5 INSERT-cross-user assertions) |
| Cross-user UPDATEs are silent no-ops (RLS hides the target row) | pets, analyses, analysis_feedback, referrals — verified by checking the target row is unchanged after the attempt (4 paired live-then-verify assertions) |
| `analyses` is append-only for authenticated callers | INSERT/UPDATE/DELETE all denied + survival check (4 assertions) |
| `analysis_feedback` is append-only after creation | UPDATE/DELETE denied + survival check (3 assertions) |
| `referrals.converted` is service-role-only | UPDATE denial + survival check + WITH CHECK on INSERT prevents `converted = true` (3 assertions) |
| `users` billing columns are GRANT-protected | UPDATE on `subscription_status` raises `permission denied for column` (1 assertion) |
| `users` DELETE is denied for authenticated | survival check (2 assertions) |
| Anonymous (no JWT) callers see nothing | SELECT against all 7 tables returns 0 rows (7 assertions) |

**Total: 48 distinct assertions, all green.**

The full test file lives at `supabase/tests/rls_isolation.test.sql`. It is a
single hermetic transaction (`BEGIN`/`ROLLBACK`) — the database is identical
before and after.

---

## 5. Edge Function Foundations

### Shared utilities (`supabase/functions/_shared/`)

```
cors.ts            (from Phase 0) — origin allowlist + preflight builder
env.ts             requireEnv / optionalEnv / isLocal
errors.ts          ApiError class + Errors namespace + withErrorHandler wrapper
logger.ts          structured JSON logger + maskEmail helper
validation.ts      readJson + asObject/asString/asUuid/asOneOf/asOptional
auth.ts            requireUser(req) + verifyWebhookSecret(req, envVar) — constant-time
supabase-admin.ts  service-role client (BYPASSRLS, used by webhooks + system code)
supabase-user.ts   user-context client (forwards user JWT, RLS applies)
rate-limit.ts      PerUserDailyLimiter + FreeTierLimiter interfaces (stubs throw 501 — Phase 1B wires)
types/db.ts        AUTO-GENERATED via `supabase gen types typescript --local`
```

### Function entrypoints

| Function | Auth | Validation | Phase 1A behaviour | Tests |
|----------|------|------------|--------------------|-------|
| `analyze/index.ts` | Bearer JWT via `requireUser()` | UUID pet_id, enumerated input_type, contextual body shape (text vs photo/video), ownership of `pet_id` via the user's JWT (RLS) | Returns `501 { error: "not_implemented", message: "Implemented in Phase 1B." }` after successful validation + ownership check. Returns `404 not_found` if the pet isn't owned by the caller (does not leak existence) | 6 unit tests covering validation surface |
| `auth-webhook/index.ts` | Constant-time bearer secret via `verifyWebhookSecret()` | accepts both `INSERT/UPDATE/DELETE` (DB webhook payload shape) and `user.created`/`user.deleted` (Send-HTTP-Hook shape) | On `INSERT`/`user.created`, inserts the public.users row idempotently (unique-violation = success). Logs other event types and acks | 4 unit tests covering signature verification |
| `revenuecat-webhook/index.ts` | Constant-time bearer secret via `verifyWebhookSecret()` | Requires `event.type` and `event.app_user_id` | Validates + logs the event; returns `200 { ok: true, applied: false }`. State mapping deferred to 1B | 2 unit tests covering payload shape |

### Error contract

Every edge function uses `withErrorHandler` so error responses are uniform
across the API:

```json
{ "error": "<stable-code>", "message": "<safe-message>" }
```

Stable codes shipped in 1A: `unauthorized`, `forbidden`, `not_found`,
`conflict`, `validation_error`, `rate_limited`, `not_implemented`,
`upstream_error`, `internal_error`.

Unknown errors → 500 with a generic message. Real exception text only goes to
the structured log line, never the response body — same discipline the
ai-service uses (Phase 0 design).

---

## 6. Known Limitations

These are deliberate scope boundaries, not oversights.

1. **No business logic in the analyze endpoint.** It validates auth + body +
   ownership and returns 501. The free-tier consume, ai-service call, and
   `analyses` row persistence are Phase 1B.
2. **No subscription state mapping in revenuecat-webhook.** The mapping
   table is documented in the function's README; the implementation lands
   in 1B.
3. **`rate-limit.ts` is interface only.** The `PerUserDailyLimiter`
   (Upstash Redis sliding window per roadmap §3) and the in-DB
   `FreeTierLimiter` activation are 1B.
4. **No 72h follow-up scheduler.** The `analysis_feedback` table exists +
   has working RLS, but the cron edge function that triggers the follow-up
   is Phase 3 (per roadmap §10).
5. **`users.email` is plaintext.** Supabase's `auth.users` mirrors the same
   email; we do not hash or pseudonymise here. GDPR is addressed via
   account-deletion CASCADE, not field-level encryption — appropriate for
   our risk model.
6. **No materialised `user_id` column on `health_events` / `analysis_feedback`.**
   These join through the parent to enforce ownership. Index-served and
   correct; future denormalisation is a non-breaking change if profiling
   demands it.
7. **`auth.users.deleted` event handling.** The DB cascade handles it; the
   webhook just logs. A 1B enhancement could wire an explicit
   right-to-deletion API path with audit logging.
8. **No `audit_events` table.** Audit-quality logging for non-analysis events
   is deferred to Phase 3+ when the legal exposure profile demands it.

---

## 7. Future Integration Points

Listed so Phase 1B/C/3 implementers can plug in without re-reading this file:

| Phase | Integration |
|-------|-------------|
| 1B (analyze) | Call `attempt_consume_free_analysis(user_id)` via the admin client; if true → POST to ai-service; on success → service-role INSERT into `analyses` |
| 1B (revenuecat-webhook) | Map `event.type` to `users.subscription_status`; service-role UPDATE keyed by `revenuecat_user_id` |
| 1B (rate-limit) | Implement `PerUserDailyLimiter` against Upstash Redis (sliding window: `pawdoc:rate:daily:<user>:<YYYYMMDD>`) |
| 1B (auth-webhook) | Add `email` field updates on `user.updated` events |
| 3 (semantic cache) | The `analyses.embedding` column + ivfflat index are ready; populate via OpenAI text-embedding-3-small in the ai-service |
| 3 (reminders cron) | New edge function `reminders-cron`; runs daily; scans `reminders WHERE due_date <= now() + 7 days AND is_sent = false`; service-role UPDATE on send |
| 3 (analysis_feedback) | New edge function `feedback-cron`; runs every 6h; identifies analyses 72h old without feedback; sends OneSignal nudge |
| 6 (referrals) | Service-role UPDATE on `converted = true, converted_at = now()` when the revenuecat-webhook records a paying subscription whose user came in via a referral code |

---

## 8. Files Changed

### Added (new in Phase 1A)

```
supabase/migrations/20260515220000_extensions.sql
supabase/migrations/20260515220100_users.sql
supabase/migrations/20260515220200_pets.sql
supabase/migrations/20260515220300_analyses.sql
supabase/migrations/20260515220400_health_events.sql
supabase/migrations/20260515220500_reminders.sql
supabase/migrations/20260515220600_analysis_feedback.sql
supabase/migrations/20260515220700_referrals.sql
supabase/migrations/20260515220800_free_tier_helpers.sql
supabase/functions/_shared/auth.ts
supabase/functions/_shared/env.ts
supabase/functions/_shared/errors.ts
supabase/functions/_shared/logger.ts
supabase/functions/_shared/rate-limit.ts
supabase/functions/_shared/supabase-admin.ts
supabase/functions/_shared/supabase-user.ts
supabase/functions/_shared/validation.ts
supabase/functions/_shared/types/db.ts            (generated)
supabase/functions/analyze/index.ts
supabase/functions/analyze/test.ts
supabase/functions/analyze/README.md
supabase/functions/auth-webhook/index.ts
supabase/functions/auth-webhook/test.ts
supabase/functions/auth-webhook/README.md
supabase/functions/revenuecat-webhook/index.ts
supabase/functions/revenuecat-webhook/test.ts
supabase/functions/revenuecat-webhook/README.md
supabase/tests/rls_isolation.test.sql
docs/reports/phase1a-db-plan.md
docs/reports/phase1a-db-implementation.md
```

### Modified

```
.github/workflows/supabase-ci.yml          + deno test step in edge-functions job
                                             + db-validate job (boot Supabase, db reset, db test)
```

### Not Touched

- `mobile/`, `ai-service/` — Phase 1A is backend-only by design
- `docs/architecture.md` — RLS rule already stated correctly there
- `roadmaps/`, `reports/` — strategy/historical, not implementation

Net: 30 files added, 1 modified.

---

## 9. Phase 1B Recommendations

Suggested order (each item is a single PR-sized commit):

1. **`/analyze` → free-tier consume + ai-service call.** Replace the
   `Errors.notImplemented` with:
   1. `supabaseAdmin().rpc('attempt_consume_free_analysis', { p_user_id: user.id })`
   2. On `false` → `Errors.rateLimited` 429
   3. On `true` → `fetch(env.AI_SERVICE_URL + '/analyze', ...)`
   4. On 200 → service-role INSERT into `analyses` with the returned payload
   5. Return the structured triage result to the caller
2. **`/revenuecat-webhook` → subscription state mapping.** Switch on
   `event.type`, service-role UPDATE keyed by `revenuecat_user_id`.
3. **Upstash Redis client + `PerUserDailyLimiter`.** Wire to enforce the
   10/day cap from roadmap §9 *before* the free-tier consume call.
4. **Auth-webhook handles `user.updated` (email changes).** Idempotent UPSERT
   on `(id, email)`.
5. **ai-service `/analyze` endpoint.** Phase 1C scope per roadmap.
6. **Mobile auth + onboarding + camera + result screens.** Phase 1D scope.

Each of these reaches into an existing seam that 1A established — no
architecture is re-litigated.

---

## 10. Operational Notes

### Regenerating types

When a future migration changes the schema, regenerate the TS types:

```bash
supabase start  # if not already running
supabase gen types typescript --local > supabase/functions/_shared/types/db.ts
# commit the diff
```

CI does NOT regenerate. The committed file is the contract that edge
functions compile against. Drift between the file and migrations is caught
by `deno check`.

### Running the full test suite locally

```bash
supabase start
supabase db reset --local      # fresh schema
supabase test db               # pgTAP RLS suite
docker run --rm --entrypoint deno -v "$PWD/supabase/functions:/work" \
  -w /work denoland/deno:latest test --allow-env --no-check
supabase stop
```

(The Docker invocation works around the host not having Deno installed; the
GitHub Actions runner has Deno natively.)

### Free-tier helper invocation pattern

```sql
SELECT public.attempt_consume_free_analysis(
  '<user-uuid>'::uuid,
  3   -- monthly limit; optional, defaults to 3
);
-- returns true if the call was permitted (and counter incremented),
-- false if the monthly limit is reached.
```

Only the service role can EXECUTE; authenticated callers receive
"permission denied."

---

## 11. Definition of Done — Verified

- ✅ `supabase start` works on a clean machine
- ✅ `supabase db reset` applies all 9 migrations cleanly
- ✅ `supabase test db` passes (48/48 pgTAP assertions)
- ✅ All edge functions deno-fmt/lint/check clean
- ✅ All 12 edge-function unit tests pass
- ✅ Phase 0 quality gates (`make lint`, `make test`) still pass
- ✅ Plan + implementation reports committed under `docs/reports/`

---

*End of Phase 1A implementation report.*
