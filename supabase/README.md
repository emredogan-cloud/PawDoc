# supabase

Database migrations + Edge Functions for PawDoc.

## Phase 0 Status

This directory ships:
- Supabase CLI config for local development
- Empty `migrations/` directory ready for Phase 1's schema
- Shared CORS helper for Edge Functions
- Empty `seed.sql`

**No schema or functions exist yet.** Phase 1 lands the full schema from
roadmap §5 and the `/analyze`, `/auth-webhook`, `/revenuecat-webhook`,
`/reminders-cron` functions.

## Local Stack

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli).

```bash
# Start: Postgres + Auth + Storage + Studio + Inbucket
supabase start

# Studio: http://127.0.0.1:54323
# API:    http://127.0.0.1:54321
# DB:     postgresql://postgres:postgres@127.0.0.1:54322/postgres

# Apply migrations + seed
supabase db reset

# Stop
supabase stop
```

The first `supabase start` downloads ~700MB of Docker images — subsequent runs
are fast.

## Migrations

Convention: `YYYYMMDDHHMMSS_<slug>.sql`. Use the CLI to generate:

```bash
supabase migration new <slug>
```

Migrations are forward-only in production. A bad migration → write a follow-up
migration to fix it; never edit a migration that has been applied to a remote.

## Edge Functions (Phase 1)

```bash
supabase functions new <name>
supabase functions serve <name>        # local
supabase functions deploy <name>       # deploy
```

All functions import shared utilities from `functions/_shared/`. The Deno
toolchain config (formatter, linter, import map) is in
`functions/_shared/deno.json`.

## Remote Project Linking

The dev and prod Supabase projects are linked from a developer's machine:

```bash
supabase link --project-ref <dev-project-ref>
supabase db push                  # apply local migrations to remote
supabase functions deploy analyze
```

Project refs live in the [Supabase Dashboard](https://supabase.com/dashboard).

## RLS Discipline

Every table created in Phase 1+ MUST have `ROW LEVEL SECURITY` enabled in its
creation migration. Tables that store user data MUST have a `users_own_<x>`
policy gated on `auth.uid()`. Migrations that create tables without RLS are
caught in CI (`supabase-ci.yml`).
