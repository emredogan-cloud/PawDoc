-- Phase 1.1 — Row Level Security (CORRECTED per owner-approved Critical Review #2).
--
-- The source roadmap's RLS was non-functional:
--   * pets/analyses had only `USING (auth.uid() = user_id)` — no WITH CHECK and
--     no INSERT path, so authenticated users could not insert their own rows;
--   * health_events/reminders had RLS enabled but NO policy -> deny-all;
--   * users/analysis_feedback/referrals had NO RLS at all -> exposed.
--
-- This migration enables RLS on every user-data table and adds complete
-- per-table policies (USING + WITH CHECK, covering SELECT/INSERT/UPDATE/DELETE
-- via FOR ALL). `(select auth.uid())` is the Supabase-recommended form (the
-- subquery is evaluated once per statement).
--
-- The AI service and Edge Functions use the service_role key, which BYPASSES
-- RLS by design — that is how /analyze writes analyses and /auth-webhook
-- creates the users row. End-user access always goes through these policies.

alter table public.users enable row level security;
alter table public.pets enable row level security;
alter table public.analyses enable row level security;
alter table public.health_events enable row level security;
alter table public.reminders enable row level security;
alter table public.analysis_feedback enable row level security;
alter table public.referrals enable row level security;

-- users: see/update only your own row. Inserts (signup) and deletes (account
-- deletion) run via the service role.
create policy users_select_own on public.users
  for select using ((select auth.uid()) = id);
create policy users_update_own on public.users
  for update using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- pets: full ownership by user_id.
create policy pets_owner on public.pets
  for all using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- analyses: owned by user_id (service role writes AI results).
create policy analyses_owner on public.analyses
  for all using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- health_events: no user_id column -> ownership derived from the parent pet.
create policy health_events_owner on public.health_events
  for all using (
    exists (
      select 1 from public.pets p
      where p.id = health_events.pet_id and p.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.pets p
      where p.id = health_events.pet_id and p.user_id = (select auth.uid())
    )
  );

-- reminders: owned by user_id.
create policy reminders_owner on public.reminders
  for all using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- analysis_feedback: no user_id -> ownership derived from the parent analysis.
create policy analysis_feedback_owner on public.analysis_feedback
  for all using (
    exists (
      select 1 from public.analyses a
      where a.id = analysis_feedback.analysis_id and a.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.analyses a
      where a.id = analysis_feedback.analysis_id and a.user_id = (select auth.uid())
    )
  );

-- referrals: owned by the referrer.
create policy referrals_owner on public.referrals
  for all using ((select auth.uid()) = referrer_user_id)
  with check ((select auth.uid()) = referrer_user_id);
