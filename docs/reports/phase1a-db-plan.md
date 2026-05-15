# Phase 1A — Database Schema + RLS + Edge Function Foundations — PLAN

**Project:** PawDoc
**Phase:** 1A (Schema + RLS + Edge Function scaffolds)
**Date:** 2026-05-15
**Authoritative source:** [`roadmaps/APP_EXECUTION_ROADMAP.md`](../../roadmaps/APP_EXECUTION_ROADMAP.md) §5 + §9
**Predecessor:** [`phase0-foundation-implementation.md`](phase0-foundation-implementation.md), [`phase0-infra-fixes.md`](phase0-infra-fixes.md)

---

## 1. Scope

Implement the database schema, RLS policies, indexes, and edge function
scaffolds defined by roadmap §5. **No business logic ships in 1A** — the
analyze, auth-webhook, and revenuecat-webhook endpoints exist as authenticated,
validated scaffolds returning 501 (or accepting/acking minimally), so the
mobile + AI service can integrate against stable contracts in 1B.

Phase 0 architecture is preserved entirely; this phase fills the `supabase/`
directory that Phase 0 left as a scaffold.

## 2. Migration Strategy

### 2.1 Discipline

- **Forward-only.** No rollback migrations. To undo, author a follow-up
  migration. Phase 0's `supabase-ci.yml` already enforces filename and RLS
  hygiene; Phase 1A doesn't change that.
- **One concern per file.** Each table gets its own migration containing the
  table, indexes, RLS enable, and per-CRUD policies. This keeps the diff per
  migration reviewable.
- **Idempotent where reasonable.** `CREATE EXTENSION IF NOT EXISTS`,
  `CREATE INDEX IF NOT EXISTS`. `CREATE TABLE` itself is intentionally NOT
  idempotent — a duplicate run signals a real problem.
- **Atomic per file.** Each migration runs in a single transaction (Supabase
  CLI default).

### 2.2 File Order

```
20260515220000_extensions.sql           -- pgvector, uuid-ossp, pgcrypto
20260515220100_users.sql                -- users table + RLS
20260515220200_pets.sql                  -- pets + indexes + RLS
20260515220300_analyses.sql              -- analyses + pgvector index + RLS
20260515220400_health_events.sql         -- health_events + RLS
20260515220500_reminders.sql             -- reminders + indexes + RLS
20260515220600_analysis_feedback.sql     -- analysis_feedback + RLS
20260515220700_referrals.sql             -- referrals + RLS
20260515220800_free_tier_helpers.sql     -- atomic free-quota consumer fn
```

Ordering is enforced by filename timestamp. No FK references a not-yet-created
table. `users` lands before everything that references it.

### 2.3 What the Roadmap Doesn't Say, but We Must Add

| Decision | Roadmap silent on it | Why it's required |
|----------|----------------------|-------------------|
| `users.id` is a FK to `auth.users.id ON DELETE CASCADE` | Yes | Without it, `auth.uid() = users.id` would not be a JOIN-ready predicate. This is the **standard** Supabase pattern — the auth-webhook inserts the row with `id = NEW.id` from the Supabase Auth trigger payload |
| Explicit per-CRUD policies (`FOR SELECT/INSERT/UPDATE/DELETE`) | Roadmap example uses a single permissive `USING` | The task brief mandates explicit policies. Explicit beats implicit for a health app |
| `CHECK` constraints on enumerated text columns | Yes | Defense-in-depth: even with a service-role bug, an invalid `triage_level` cannot be persisted |
| RLS on `users`, `analysis_feedback`, `referrals` | Roadmap only enables RLS on pets/analyses/health_events/reminders | These tables also store user-owned data. Phase 0 CI lint requires it. Health app standard |
| `seed.sql` keeps Phase 0's NO-OP form | Roadmap silent | Local dev creates users via Studio; pre-seeded users without matching auth.users would be orphans |

## 3. Schema Decisions

### 3.1 Tables

| Table | Owner key | Cascade behaviour | Append-only? |
|-------|-----------|-------------------|--------------|
| `users` | `id = auth.users.id` | DELETE auth.users → CASCADE delete public.users → CASCADE all child rows | No (users can update their own profile) |
| `pets` | `user_id` | DELETE user CASCADE; UPDATE allowed | No |
| `analyses` | `user_id` (also `pet_id`) | DELETE user CASCADE; pet FK has NO ACTION (analyses outlive deleted pets — legal record per §9) | **YES** — UPDATE/DELETE denied at RLS level |
| `health_events` | `pet_id → pets.user_id` | DELETE pet CASCADE | No |
| `reminders` | `user_id` (also `pet_id`) | DELETE user/pet CASCADE | No |
| `analysis_feedback` | `analysis_id → analyses.user_id` | DELETE analysis CASCADE (would only happen via account deletion) | **YES** — UPDATE/DELETE denied |
| `referrals` | `referrer_user_id` | DELETE user CASCADE | No (UPDATE only by service role for `converted` flag) |

**Critical detail — analyses.pet_id NO CASCADE:** the roadmap §5 shows
`pet_id uuid REFERENCES pets(id)` with no cascade specified. We make this
explicit: `ON DELETE NO ACTION` — deleting a pet must NOT delete its analysis
history. The legal record (per roadmap §9 "Analysis logging") must persist
independently. We tombstone pets via `is_active = false` rather than physical
delete.

Conversely, `analyses.user_id ON DELETE CASCADE` is correct: GDPR right-to-
deletion requires that a user account deletion removes all the user's data,
including analyses. This is a legal trade-off; the analysis log persists for
*active* users, and is purged with the user.

### 3.2 Check Constraints

```sql
-- users
CHECK (subscription_status IN ('free', 'trial', 'premium', 'family'))

-- pets
CHECK (species IN ('dog', 'cat', 'rabbit', 'bird', 'reptile', 'other'))
CHECK (sex IS NULL OR sex IN ('male', 'female', 'unknown'))
CHECK (weight_kg IS NULL OR weight_kg > 0)

-- analyses
CHECK (input_type IN ('photo', 'video', 'text'))
CHECK (triage_level IS NULL OR triage_level IN ('EMERGENCY', 'MONITOR', 'NORMAL'))
CHECK (tier_used IS NULL OR tier_used IN (2, 3, 4))
CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1))

-- health_events
CHECK (event_type IN ('vaccination', 'vet_visit', 'medication', 'weight', 'custom'))

-- reminders
CHECK (reminder_type IN ('vaccination', 'medication', 'vet_visit', 'follow_up', 'custom'))

-- analysis_feedback
CHECK (outcome IS NULL OR outcome IN ('resolved_on_own', 'vet_confirmed', 'vet_said_nothing', 'still_monitoring', 'other'))
CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5))
```

These mirror the comments in the roadmap schema. They convert "ambiguous text
field with documentation" into "enforced enumeration." A future migration can
relax or extend them; relaxing is safe, tightening would require a backfill.

### 3.3 Indexes

Identical to roadmap §5:

```sql
CREATE INDEX idx_analyses_pet_id           ON analyses(pet_id);
CREATE INDEX idx_analyses_user_id_created  ON analyses(user_id, created_at DESC);
CREATE INDEX idx_analyses_triage_level     ON analyses(triage_level);
CREATE INDEX idx_pets_user_id              ON pets(user_id) WHERE is_active = true;
CREATE INDEX idx_reminders_due             ON reminders(due_date) WHERE is_sent = false;
CREATE INDEX idx_users_subscription        ON users(subscription_status);

-- pgvector
CREATE INDEX idx_analyses_embedding        ON analyses USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);
```

Plus one safety index not in the roadmap:

```sql
CREATE INDEX idx_referrals_referrer        ON referrals(referrer_user_id);
```

— needed for the RLS predicate to be index-served (otherwise SELECT under RLS
scans the table).

### 3.4 Defaults

All as per roadmap §5. Notably:
- `users.free_analyses_reset_at` defaults to `date_trunc('month', now()) + interval '1 month'` — start-of-next-month
- `users.subscription_status` defaults to `'free'`
- All `created_at` columns default to `now()`

### 3.5 pgvector Preparation

- Extension enabled in 00_extensions.sql.
- `analyses.embedding vector(1536)` — sized for OpenAI's `text-embedding-3-small` (matches roadmap §3 Tier-2/3 architecture).
- ivfflat index with `lists = 100` per roadmap §5. Note: ivfflat performance gets a bump from `ANALYZE` after data lands; this is a Phase 3+ tuning concern.

## 4. RLS Strategy

### 4.1 Defaults

- RLS **enabled on every user-facing table**, not just the four the roadmap
  lists explicitly.
- **Default-deny.** A table with RLS enabled but no permissive policy denies
  all access. We rely on this default but ALSO ship explicit policies for the
  four CRUD operations, so the intent is auditable.
- `service_role` bypasses RLS automatically (Postgres `BYPASSRLS`). All writes
  by ai-service and edge functions use the service-role key. **No
  user-facing write path exists for analyses**.

### 4.2 Policy Matrix

(✅ = explicit permissive policy for own data; 🚫 = explicit deny policy;
⚙️ = service-role only, no user policy.)

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| `users` | ✅ `auth.uid() = id` | ⚙️ service role | ✅ `auth.uid() = id` (limited columns — see 4.3) | 🚫 explicit deny (account deletion goes via service-role flow) |
| `pets` | ✅ `auth.uid() = user_id` | ✅ `auth.uid() = user_id` | ✅ `auth.uid() = user_id` | ✅ `auth.uid() = user_id` |
| `analyses` | ✅ `auth.uid() = user_id` | 🚫 deny (ai-service writes via service role) | 🚫 deny (append-only) | 🚫 deny (append-only) |
| `health_events` | ✅ user owns parent pet | ✅ user owns parent pet | ✅ user owns parent pet | ✅ user owns parent pet |
| `reminders` | ✅ `auth.uid() = user_id` | ✅ `auth.uid() = user_id` | ✅ `auth.uid() = user_id` | ✅ `auth.uid() = user_id` |
| `analysis_feedback` | ✅ user owns parent analysis | ✅ user owns parent analysis | 🚫 deny (append-only) | 🚫 deny (append-only) |
| `referrals` | ✅ `auth.uid() = referrer_user_id` | ✅ `auth.uid() = referrer_user_id` | 🚫 deny (service role marks `converted`) | 🚫 deny |

### 4.3 Restricted-column UPDATE on `users`

User SELF-update via authenticated client should be restricted to "profile"
columns: `preferred_locale`, `last_active_at`. Subscription/billing columns
(`subscription_status`, `subscription_tier`, `revenuecat_user_id`,
`free_analyses_used_this_month`, `free_analyses_reset_at`) MUST be writeable
only by service role.

The cleanest enforcement is a column-level revocation (Postgres GRANT). RLS
gates rows; column grants gate columns. Both apply.

```sql
-- After RLS update policy is in place:
REVOKE UPDATE ON users FROM authenticated;
GRANT UPDATE (preferred_locale, last_active_at) ON users TO authenticated;
```

This is more defensive than a trigger that nulls back changes. Bad
write → permission denied at column level, regardless of RLS.

### 4.4 The "Pet → User" Ownership Chain

`health_events` and `analysis_feedback` don't store `user_id` directly. Their
RLS predicate joins through the parent:

```sql
CREATE POLICY "health_events_select_own" ON health_events FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM pets p WHERE p.id = health_events.pet_id AND p.user_id = auth.uid()
  ));
```

This is acceptable because:
- The lookup is index-served (PK on pets, FK on pet_id, both indexed).
- A SELECT EXISTS subquery is cheap (single index seek).
- The alternative — denormalising `user_id` onto every child table — adds
  data-integrity burden and contradicts roadmap §5.

For ON DELETE behaviour, `pets.id` cascade means a deleted pet drops the
health_events naturally, so the policy is also future-proof against orphans.

### 4.5 Why NOT Add `user_id` Directly to `health_events` / `analysis_feedback`

Roadmap §5 doesn't denormalise. Adding it would:
- Introduce drift risk: pet's user_id changes (e.g. transfer ownership later) → analyses inconsistent
- Require a NOT NULL constraint we'd then need to populate
- Need a trigger to keep in sync

The join-based policy is the correct call given the schema. If query plans
prove it's slow at scale (>100K events/user), we can add a generated column
or materialised denormalisation later — that migration is non-breaking.

## 5. Security Considerations

### 5.1 Hard Rules That Must Hold Post-1A

1. **Cross-user data access is impossible** through the authenticated API.
   Tested by pgTAP isolation suite.
2. **No user-facing write to `analyses`** — the table is append-only from the
   user's perspective. Only the ai-service (service role) writes.
3. **No user-facing write to billing/subscription columns** of `users` —
   GRANT-controlled, enforced even if a future policy bug appears.
4. **Service-role key is never embedded in the mobile app.** It lives in
   ai-service + edge functions only.
5. **Free-tier counter writes are server-side, atomic.** Implemented as a
   stored function with `SELECT ... FOR UPDATE` (Phase 1B will call it).
6. **All `CHECK` constraints fire on every INSERT/UPDATE.** Bad data → fail
   loud, never silent corruption.

### 5.2 Rate-Limit Preparation

The edge function `analyze` will need rate limiting:
- Roadmap §9: max 10 analyses/day/user.
- Free tier: 3 analyses/month (already a counter on `users`).

We'll add the schema seed for rate-limit data in 1A:

```sql
-- Phase 1B activates this; the column exists from 1A.
ALTER TABLE users ADD COLUMN daily_analysis_window_start timestamptz;
ALTER TABLE users ADD COLUMN daily_analyses_used int DEFAULT 0;
```

…wait — adding columns the roadmap doesn't list would be scope creep.
Defer: 1B will add a separate migration if/when needed; the in-memory
counter in edge functions (sliding window via Redis/Upstash) may be the
better fit. The rate-limit prep in 1A is the **edge function helper
scaffold**, not a schema addition. See §6.

### 5.3 Auditability

Every analysis is permanently logged with its full input + output + model
metadata. The analyses table IS the audit log. Append-only RLS ensures that
the user cannot retroactively edit "what the AI said."

A separate `audit_events` table for non-analysis auditing (logins, profile
edits) is deferred to Phase 3+ when the legal exposure profile demands it.

## 6. Edge Function Architecture

### 6.1 Shared Utilities (`supabase/functions/_shared/`)

All files are tree-shaken at deploy time — only what's imported by a function
ends up in its bundle. Shared helpers live here:

```
_shared/
├── cors.ts                  (exists from Phase 0)
├── env.ts                   typed env access with validation
├── errors.ts                ApiError class + JSON error responses
├── logger.ts                structured JSON logging
├── auth.ts                  JWT extraction + verification helpers
├── supabase-admin.ts        service-role client factory
├── supabase-user.ts         user-context client (forwards user JWT)
├── rate-limit.ts            in-memory token bucket + DB-backed counter helpers (interface, no implementation)
└── types/
    └── db.ts                generated by `supabase gen types typescript --local`
```

### 6.2 Function Contracts

| Function | Auth | Phase 1A behaviour | Phase 1B/C behaviour |
|----------|------|---------------------|----------------------|
| `analyze` | Bearer JWT required; validated via `_shared/auth.ts` | Validate request body shape → ownership check (pet_id belongs to user) → return `501 { "code": "not_implemented", "phase": "1B" }` | Free-tier consume → call ai-service → store result → return triage |
| `auth-webhook` | HMAC over body via `SUPABASE_AUTH_WEBHOOK_SECRET` (Supabase sends `Authorization: Bearer <secret>`) | Verify secret → validate payload schema → INSERT into `public.users` on `user.created` (idempotent) → ack | Add `user.deleted` handler (cascades naturally) |
| `revenuecat-webhook` | HMAC over body via `REVENUECAT_WEBHOOK_AUTH_TOKEN` | Verify token → validate payload schema → no-op except logging → ack | Map event_type → subscription_status, write to `users` |

### 6.3 Request Validation

Every function uses a `zod`-equivalent **Deno-native validation**. Rather than
pull in `zod` (npm pkg, esm.sh proxy, supply-chain) for trivial schemas, we
hand-roll type guards in `_shared/types/` for each function's payload.
Acceptable because:
- Each function has 1-2 payload shapes total
- Type guards are 10-15 lines
- Avoids importing arbitrary JS into a security-sensitive runtime

This is consistent with roadmap §9 ("Input validation on all endpoints"):
explicit > dependency.

### 6.4 Auth Verification

`_shared/auth.ts` exports:

```ts
async function requireUser(req: Request): Promise<{ id: string; jwt: string }>
```

- Pulls `Authorization: Bearer <jwt>` from request headers
- Calls Supabase Auth's `getUser(jwt)` via admin client (which uses the
  internal `auth.users` table; trusts Supabase's own JWT signature)
- Returns `id` (the `auth.users.id` aka `auth.uid()`) or throws `Unauthorized`

For webhooks, `_shared/auth.ts` also exports:

```ts
function verifyWebhookSecret(req: Request, envVar: string): void
```

- Constant-time comparison of `Authorization: Bearer <secret>` to the env
  var
- Throws `Unauthorized` on mismatch

### 6.5 Structured Errors

```ts
class ApiError extends Error {
  readonly status: number
  readonly code: string
  constructor(status: number, code: string, message: string)
  toResponse(): Response
}
```

Function handlers wrap their body in `try/catch`; all `ApiError`s map to the
JSON shape `{ "error": "<code>", "message": "<message>" }` with the
appropriate HTTP status. Unknown errors → 500 with generic message (the same
discipline the ai-service uses, per Phase 0 design).

### 6.6 Logging

`_shared/logger.ts` exposes `log(level, msg, ctx)` that emits JSON to stdout.
Supabase Edge captures stdout into the dashboard. Same contract as the AI
service: never log raw secrets, never log user emails in production.

### 6.7 What Each Function Does NOT Do in 1A

- `analyze`: does NOT call the ai-service. Does NOT consume free-tier quota.
  Does NOT write to `analyses`. The endpoint exists to lock the contract.
- `auth-webhook`: does NOT yet handle `user.deleted` (we'll do it in 1B; the
  current scaffold ignores unknown event types).
- `revenuecat-webhook`: does NOT map RevenueCat event types to subscription
  state changes. It validates + acks only.

## 7. Testing Strategy

### 7.1 pgTAP RLS Isolation Suite

Lives in `supabase/tests/rls/`. Each test file uses pgTAP. Supabase CLI
ships pgTAP locally; `supabase db test` runs the suite.

| File | Asserts |
|------|---------|
| `users.test.sql` | A user can SELECT their own row; cannot SELECT another's; cannot UPDATE billing columns; cannot DELETE |
| `pets.test.sql` | A user can CRUD their own pets; cannot SELECT another's; cannot INSERT another's |
| `analyses.test.sql` | A user can SELECT their own analyses; cannot SELECT another's; INSERT/UPDATE/DELETE always denied for any user (service-role only) |
| `health_events.test.sql` | A user can CRUD events on their own pets; cannot SELECT events on another's pet |
| `reminders.test.sql` | Same as pets |
| `analysis_feedback.test.sql` | A user can SELECT/INSERT feedback on own analyses; cannot UPDATE/DELETE; cannot reach other users' feedback |
| `referrals.test.sql` | A user can SELECT/INSERT own referrals; cannot UPDATE the `converted` flag (service-role only) |

Each test creates two test users via `auth.users` direct insert (legal under
service-role test context), runs the assertions impersonating one then the
other via `SET LOCAL ROLE authenticated; SET LOCAL "request.jwt.claims" = ...`,
and asserts the expected behaviour.

### 7.2 Edge Function Tests

A `tests/deno.test.ts` per function that:
- Mocks `Deno.env.get` with test values
- Verifies happy path returns expected status
- Verifies missing/bad auth returns 401
- Verifies malformed body returns 422

Runs via `deno test --allow-env --allow-net=...`. Added to the
`supabase-ci.yml` workflow.

### 7.3 CI Updates

`supabase-ci.yml` gains:

1. **New job: `db-validate`.** Boots Supabase locally on the runner, runs
   `supabase db reset` (applies all migrations + seed), then `supabase db
   test`. Caches the Supabase Docker images.
2. **Existing `edge-functions` job: extend** to also `deno test --check`
   each function directory.

Net runtime impact: ~+60s for image pull on first run, ~+15s cached.
Acceptable; this is the test that prevents the worst class of bug.

## 8. Rollback Risks

Forward-only migrations mean we cannot "roll back." We can only fix forward.

| Risk | Severity | Mitigation |
|------|----------|------------|
| Migration applies on dev but fails on prod due to data shape | Medium | Migrations run in a transaction; failure aborts cleanly. CI's `db-validate` job catches it pre-merge |
| RLS policy with a subtle bug ships to prod | **Critical** | pgTAP suite is gating; explicit per-CRUD policies; column GRANTs as defence-in-depth |
| `auth.uid()` returns NULL in some edge case → policy evaluates `NULL = user_id` → false → access denied (safe-fail) | Low | pgTAP test that asserts unauthenticated callers cannot SELECT |
| Wrong cascade dropped data (e.g. analyses CASCADE'd by pet delete) | High | Explicit `ON DELETE NO ACTION` on `analyses.pet_id`; pgTAP test that deletes a pet and asserts analyses remain |
| pgvector index becomes stale because no `ANALYZE` after backfill | Low | Phase 3 concern — pgvector docs cover; no Phase 1A data volume |
| Phase 1B writes assume a column we didn't add in 1A | Low | Phase 1B will add its own migrations; nothing in 1A precludes later additions |

## 9. Implementation Order

1. **Plan committed** (this file).
2. **Migrations** (`supabase/migrations/`):
   - 00_extensions
   - 01_users
   - 02_pets
   - 03_analyses
   - 04_health_events
   - 05_reminders
   - 06_analysis_feedback
   - 07_referrals
   - 08_free_tier_helpers (the `attempt_consume_free_analysis` SQL function)
3. **Edge function shared utilities** (`supabase/functions/_shared/`).
4. **Edge function scaffolds**:
   - `analyze/`
   - `auth-webhook/`
   - `revenuecat-webhook/`
5. **pgTAP tests** (`supabase/tests/rls/`).
6. **CI extension** (`.github/workflows/supabase-ci.yml`).
7. **Validation**: `supabase db reset && supabase db test`, deno fmt/lint/check, full `make lint && make test`.
8. **Implementation report** (`docs/reports/phase1a-db-implementation.md`).

## 10. Files Added / Modified

### Added
- 9 migration files in `supabase/migrations/`
- 7-8 files in `supabase/functions/_shared/` (env, errors, logger, auth, supabase-admin, supabase-user, rate-limit, types/db.ts)
- 3 edge function entrypoints (`analyze/index.ts`, `auth-webhook/index.ts`, `revenuecat-webhook/index.ts`) + their per-function `deno.test.ts`
- 7 pgTAP test files in `supabase/tests/rls/`
- `supabase/tests/setup.sql` — helpers used by every test file (creating test users etc.)
- This plan doc + the implementation doc

### Modified
- `.github/workflows/supabase-ci.yml` — new `db-validate` job, extended edge-functions job
- `supabase/README.md` — update for migration workflow
- (no Phase 0 architecture artifacts touched)

### Not Touched
- `mobile/`, `ai-service/` (Phase 1A is backend-only)
- `roadmaps/`, `reports/` (strategy docs)

## 11. Open Questions / Deferred

These are explicitly out of 1A:

1. **`auth.users.deleted` cascading.** Supabase's auth admin API and the
   public.users FK cascade handle it. 1B will add a webhook handler for
   GDPR-style explicit deletion (separate from auth.users delete).
2. **Account deletion UX.** Phase 2.
3. **Subscription state machine** (free → trial → premium → family + cancel
   handling). Phase 1B in the revenuecat-webhook.
4. **Rate-limit token bucket implementation.** Phase 1B. The scaffold in
   `_shared/rate-limit.ts` is a typed interface only.
5. **Embedding generation pipeline.** Phase 3 (semantic cache).
6. **Audit log table for non-analysis events.** Phase 3+ — RoI not justified
   for Phase 1.

## 12. Definition of Done

- `supabase db reset` succeeds locally and in CI.
- `supabase db test` passes (all RLS pgTAP tests green).
- `deno fmt --check && deno lint && deno check **/*.ts` pass in
  `supabase/functions/`.
- `make lint && make test` from Phase 0 still pass.
- `phase1a-db-implementation.md` documents the result.
- `docs/architecture.md` does not require updates (RLS rule already stated).

---

*End of Phase 1A plan. Implementation follows.*
