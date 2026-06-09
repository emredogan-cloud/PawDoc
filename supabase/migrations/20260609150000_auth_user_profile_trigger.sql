-- Phase A (pre-launch hardening) — guarantee public.users provisioning.
--
-- ROOT CAUSE (found during live on-device E2E validation, 2026-06-09):
-- a real, confirmed, signed-in auth user had NO public.users row. The roadmap
-- provisions that row via the /auth-webhook Edge Function configured as a
-- Supabase Auth Hook — but the hook is NOT wired in config.toml and did not
-- fire for the signup. With no public.users row:
--   * users_create_solo_family (AFTER INSERT on public.users) never ran -> the
--     user has no solo family group;
--   * users_set_referral_code never ran -> no referral code;
--   * the first real action (add a pet) fails: the pets_default_family_group
--     BEFORE-INSERT trigger cannot resolve the owner's group, so the
--     pets_insert_own_in_family RLS WITH CHECK rejects the row (SQLSTATE 42501,
--     surfaced to the user as "Could not save your pet. Try again.").
--
-- This is exactly the "belt-and-braces" Postgres trigger that the auth-webhook
-- source comment flags as "a strictly more robust way to guarantee the profile
-- row (no network, unforgeable)". It runs in the same transaction as the
-- auth.users insert and is idempotent (ON CONFLICT DO NOTHING), so it coexists
-- safely with the Edge-Function Auth Hook if that is ever enabled too.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Minimal seed; the AFTER-INSERT triggers on public.users fill in the
  -- referral code and create the solo family group. Everything else defaults.
  insert into public.users (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- One-time backfill: provision every existing auth user missing a profile row.
-- The AFTER-INSERT triggers on public.users (referral code + solo family group)
-- fire per backfilled row, so previously-stranded accounts become fully usable.
insert into public.users (id, email)
select au.id, au.email
from auth.users au
left join public.users pu on pu.id = au.id
where pu.id is null
on conflict (id) do nothing;
