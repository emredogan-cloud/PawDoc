-- Phase 3.3 (Part 2) — Engagement query helpers + the re-engagement guard.
--
-- These are the SET-of-rows the cron-driven /process-reminders Edge Function
-- acts on. Kept as SECURITY DEFINER functions (locked to the service role) so:
--   * the logic + timezone handling live in ONE place (the DB), unit-testable
--     against real Postgres without the managed cron extensions;
--   * the Edge Function just iterates rows and calls OneSignal.
-- The pg_cron/pg_net SCHEDULE is a separate migration (Supabase-managed
-- extensions), applied by the founder on the project.

-- No-spam guard for the inactivity re-engagement push (strict rule).
alter table public.users add column last_reengagement_sent_at timestamptz;

-- Reminders that are DUE and not yet sent, with the owner's push id.
-- Timezone: due_date is a calendar DATE (no time/zone). We compare against the
-- current date in UTC so evaluation is deterministic regardless of server tz;
-- with hourly cron + day-granular reminders, a reminder fires within an hour of
-- UTC midnight on its due day. (Per-user timezone is a documented future refinement.)
create or replace function public.due_reminders()
returns table (
  id uuid,
  pet_id uuid,
  user_id uuid,
  reminder_type text,
  due_date date,
  player_id text
)
language sql
stable
security definer
set search_path = public
as $$
  select r.id, r.pet_id, r.user_id, r.reminder_type, r.due_date, u.one_signal_player_id
  from public.reminders r
  join public.users u on u.id = r.user_id
  where r.is_sent = false
    and r.due_date <= (now() at time zone 'utc')::date
    and u.one_signal_player_id is not null;
$$;

-- Users to nudge with a gentle "we miss you" push:
--   * have a push id;
--   * account older than inactivity_days (don't pester brand-new signups);
--   * no analysis within inactivity_days (lapsed);
--   * NOT re-engaged within cooldown_days (the no-spam guard).
create or replace function public.users_to_reengage(inactivity_days int, cooldown_days int)
returns table (user_id uuid, player_id text)
language sql
stable
security definer
set search_path = public
as $$
  select u.id, u.one_signal_player_id
  from public.users u
  where u.one_signal_player_id is not null
    and u.created_at < now() - make_interval(days => inactivity_days)
    and (
      u.last_reengagement_sent_at is null
      or u.last_reengagement_sent_at < now() - make_interval(days => cooldown_days)
    )
    and not exists (
      select 1 from public.analyses a
      where a.user_id = u.id
        and a.created_at >= now() - make_interval(days => inactivity_days)
    );
$$;

-- Lockdown: only the service role (the Edge Function) may call these.
revoke all on function public.due_reminders() from public, anon, authenticated;
revoke all on function public.users_to_reengage(int, int) from public, anon, authenticated;
grant execute on function public.due_reminders() to service_role;
grant execute on function public.users_to_reengage(int, int) to service_role;
