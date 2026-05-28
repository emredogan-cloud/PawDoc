-- Phase 5.3 — AI Health Journal (weekly GPT-4o narrative per pet).
--
-- Storage + eligibility query. RLS: clients can READ their own pet's journal
-- only; INSERT/UPDATE/DELETE are server-only (writes happen in the cron Edge
-- function via service_role). UNIQUE (pet_id, week_start_date) makes the cron
-- idempotent — a re-run for the same week never duplicates a row.
--
-- Tier gate + opt-in: pets.is_journal_enabled is a new opt-in flag; eligibility
-- additionally requires the owning user to be on Premium/Family/Trial.

-- 1. Schema --------------------------------------------------------------------
alter table public.pets add column is_journal_enabled boolean not null default false;

create table public.health_journals (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  narrative_text text not null,
  week_start_date date not null,
  model_used text,
  created_at timestamptz not null default now(),
  unique (pet_id, week_start_date) -- idempotency for the weekly cron
);

create index idx_health_journals_user_week on public.health_journals (user_id, week_start_date desc);

-- 2. RLS ---------------------------------------------------------------------
alter table public.health_journals enable row level security;

-- Clients can READ their own journals only; writes go through the cron Edge
-- function (service_role bypasses RLS + has the grants below).
create policy health_journals_select_own on public.health_journals
  for select using ((select auth.uid()) = user_id);

-- Belt + braces: revoke client writes at the table-grant level too.
revoke insert, update, delete on public.health_journals from anon, authenticated;

-- 3. Eligibility RPC (server-only) --------------------------------------------
-- Returns pets that are: opt-in (is_journal_enabled), owned by an active
-- subscriber, and don't already have a journal for the given week.
create or replace function public.pets_pending_journal(week_start date)
returns table (pet_id uuid, user_id uuid, species text, breed text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.user_id, p.species, p.breed
  from public.pets p
  join public.users u on u.id = p.user_id
  where p.is_active = true
    and p.is_journal_enabled = true
    and u.subscription_status in ('premium', 'family', 'trial')
    and not exists (
      select 1 from public.health_journals j
      where j.pet_id = p.id and j.week_start_date = week_start
    );
$$;

revoke all on function public.pets_pending_journal(date) from public, anon, authenticated;
grant execute on function public.pets_pending_journal(date) to service_role;
