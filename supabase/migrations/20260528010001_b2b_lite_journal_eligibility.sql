-- Phase 5.4 — extend the journal-eligibility RPC to include the new b2b_lite
-- (sitter) tier. The 5.3 RPC limited eligibility to {premium, family, trial};
-- sitters paying $19.99/mo expect the same premium features.
--
-- Locked to service_role exactly like the 5.3 version (cron-only).

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
    and u.subscription_status in ('premium', 'family', 'trial', 'b2b_lite')
    and not exists (
      select 1 from public.health_journals j
      where j.pet_id = p.id and j.week_start_date = week_start
    );
$$;

revoke all on function public.pets_pending_journal(date) from public, anon, authenticated;
grant execute on function public.pets_pending_journal(date) to service_role;
