-- Phase 6.3 — Family Sharing schema + RLS redesign.
--
-- This is the most security-sensitive migration in the codebase: it converts
-- pets/analyses/health_events/reminders from "per-user RLS" to "per-family-
-- group RLS" while preserving the existing per-user semantics for users who
-- don't share with anyone (the SAFE default).
--
-- Design choices (each one matters):
--
--   1. EVERY user has at least ONE family_group — their "solo" household. A
--      trigger on public.users creates it on signup; the migration backfills
--      one for every existing user. Standalone users are simply members of a
--      group of size 1 → the new RLS path collapses to the old behavior for
--      them, so we never have to special-case NULL family_group_id.
--
--   2. RECURSION is avoided via two SECURITY DEFINER helper functions:
--      `is_family_member(group_id)` and `is_family_pet(pet_id)`. They run as
--      the function owner and BYPASS RLS on family_members — so the RLS
--      policy on family_members itself can call `is_family_member(group_id)`
--      without recursing back into its own USING clause.
--
--   3. UPDATE/DELETE on row-owned tables (pets, analyses, reminders) stays
--      owner-only (`user_id = auth.uid()`) — we share the VIEW, not the
--      KEYS — so a family member can't accidentally rename / delete the
--      pet they don't own. SELECT and INSERT are group-wide (any member can
--      log an analysis or a health event on a family pet — that's the
--      killer use case).
--
--   4. pets.family_group_id has a BEFORE-INSERT trigger that defaults it to
--      the owner's solo group when the client doesn't supply one — so
--      existing client code keeps working without knowing the column exists.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

create table public.family_groups (
  id uuid primary key default gen_random_uuid(),
  name text default 'My household',
  owner_user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz default now()
);

create index family_groups_owner_idx on public.family_groups (owner_user_id);

create table public.family_members (
  group_id uuid not null references public.family_groups (id) on delete cascade,
  user_id  uuid not null references public.users (id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'member')),
  joined_at timestamptz default now(),
  primary key (group_id, user_id)
);

-- Reverse-direction index for the per-user lookup the helpers do.
create index family_members_user_id_idx on public.family_members (user_id);

-- ---------------------------------------------------------------------------
-- 2. Backfill: every existing user gets a solo family group.
-- ---------------------------------------------------------------------------

insert into public.family_groups (owner_user_id, name)
  select u.id, 'My household'
  from public.users u
  where not exists (
    select 1 from public.family_groups fg where fg.owner_user_id = u.id
  );

insert into public.family_members (group_id, user_id, role)
  select fg.id, fg.owner_user_id, 'owner'
  from public.family_groups fg
  where not exists (
    select 1 from public.family_members fm
    where fm.group_id = fg.id and fm.user_id = fg.owner_user_id
  );

-- ---------------------------------------------------------------------------
-- 3. pets.family_group_id + backfill (BEFORE creating any function or policy
--    that references this column; LANGUAGE SQL functions are parsed at CREATE
--    time and would fail if the column didn't exist yet).
-- ---------------------------------------------------------------------------

alter table public.pets
  add column if not exists family_group_id uuid references public.family_groups (id) on delete restrict;

update public.pets p
set family_group_id = (
  select fg.id from public.family_groups fg
  where fg.owner_user_id = p.user_id
  order by fg.created_at asc
  limit 1
)
where family_group_id is null;

alter table public.pets alter column family_group_id set not null;
create index pets_family_group_id_idx on public.pets (family_group_id);

-- ---------------------------------------------------------------------------
-- 4. SECURITY DEFINER helpers — these break the would-be RLS recursion
--    by bypassing RLS on family_members. They are STABLE (one-shot per
--    statement) and constrain themselves to auth.uid() so they cannot leak
--    membership data across users.
-- ---------------------------------------------------------------------------

create or replace function public.is_family_member(check_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.family_members
    where group_id = check_group_id
      and user_id  = auth.uid()
  );
$$;

create or replace function public.is_family_pet(check_pet_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.pets p
    join public.family_members fm on fm.group_id = p.family_group_id
    where p.id = check_pet_id
      and fm.user_id = auth.uid()
  );
$$;

revoke all on function public.is_family_member(uuid) from public;
revoke all on function public.is_family_pet(uuid) from public;
grant execute on function public.is_family_member(uuid) to authenticated, service_role;
grant execute on function public.is_family_pet(uuid)    to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Convenience triggers — keep the existing client code working as-is.
-- ---------------------------------------------------------------------------

-- Default the pet's family_group_id to the owner's solo group when the client
-- doesn't supply it. PetsRepository on the client doesn't know about the new
-- column; this trigger fills it in transparently.
create or replace function public.default_pet_family_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.family_group_id is null then
    select fg.id into new.family_group_id
    from public.family_groups fg
    where fg.owner_user_id = new.user_id
    order by fg.created_at asc
    limit 1;
  end if;
  return new;
end;
$$;

create trigger pets_default_family_group
  before insert on public.pets
  for each row execute function public.default_pet_family_group();

-- Signup trigger — every new user automatically gets a solo group. The
-- auth-webhook inserts public.users; this fires AFTER.
create or replace function public.create_solo_family_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_group_id uuid;
begin
  insert into public.family_groups (owner_user_id, name)
  values (new.id, 'My household')
  returning id into new_group_id;
  insert into public.family_members (group_id, user_id, role)
  values (new_group_id, new.id, 'owner');
  return new;
end;
$$;

create trigger users_create_solo_family
  after insert on public.users
  for each row execute function public.create_solo_family_for_new_user();

-- ---------------------------------------------------------------------------
-- 6. Replace per-user RLS with family-aware RLS.
--    SELECT + INSERT: group-wide (any member can see + log on a family pet).
--    UPDATE / DELETE: owner-only (the row's `user_id`) for row-owned tables
--      (pets / analyses / reminders). health_events has no user_id, so the
--      whole family can edit/delete its rows (low-stakes metadata).
-- ---------------------------------------------------------------------------

alter table public.family_groups   enable row level security;
alter table public.family_members  enable row level security;

create policy family_groups_select_member on public.family_groups
  for select using (public.is_family_member(id));
create policy family_groups_insert_owner on public.family_groups
  for insert with check ((select auth.uid()) = owner_user_id);
create policy family_groups_update_owner on public.family_groups
  for update using ((select auth.uid()) = owner_user_id)
                with check ((select auth.uid()) = owner_user_id);
create policy family_groups_delete_owner on public.family_groups
  for delete using ((select auth.uid()) = owner_user_id);

-- family_members: SELECT goes through the SECURITY DEFINER helper to avoid
-- self-recursion. INSERT is restricted to the group's owner. DELETE allows
-- self-removal OR removal by the group's owner.
create policy family_members_select on public.family_members
  for select using (public.is_family_member(group_id));
create policy family_members_insert_by_owner on public.family_members
  for insert with check (
    exists (
      select 1 from public.family_groups fg
      where fg.id = family_members.group_id
        and fg.owner_user_id = (select auth.uid())
    )
  );
create policy family_members_delete_self_or_owner on public.family_members
  for delete using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.family_groups fg
      where fg.id = family_members.group_id
        and fg.owner_user_id = (select auth.uid())
    )
  );

-- pets
drop policy if exists pets_owner on public.pets;
create policy pets_select_family on public.pets
  for select using (public.is_family_member(family_group_id));
create policy pets_insert_own_in_family on public.pets
  for insert with check (
    (select auth.uid()) = user_id
    and public.is_family_member(family_group_id)
  );
create policy pets_update_owner on public.pets
  for update using ((select auth.uid()) = user_id)
                with check ((select auth.uid()) = user_id);
create policy pets_delete_owner on public.pets
  for delete using ((select auth.uid()) = user_id);

-- analyses
drop policy if exists analyses_owner on public.analyses;
create policy analyses_select_family on public.analyses
  for select using (public.is_family_pet(pet_id));
create policy analyses_insert_member on public.analyses
  for insert with check (
    (select auth.uid()) = user_id
    and public.is_family_pet(pet_id)
  );
create policy analyses_update_owner on public.analyses
  for update using ((select auth.uid()) = user_id)
                with check ((select auth.uid()) = user_id);
create policy analyses_delete_owner on public.analyses
  for delete using ((select auth.uid()) = user_id);

-- health_events (no user_id — family-wide for all 4 verbs)
drop policy if exists health_events_owner on public.health_events;
create policy health_events_select_family on public.health_events
  for select using (public.is_family_pet(pet_id));
create policy health_events_insert_member on public.health_events
  for insert with check (public.is_family_pet(pet_id));
create policy health_events_update_member on public.health_events
  for update using (public.is_family_pet(pet_id))
                with check (public.is_family_pet(pet_id));
create policy health_events_delete_member on public.health_events
  for delete using (public.is_family_pet(pet_id));

-- reminders
drop policy if exists reminders_owner on public.reminders;
create policy reminders_select_family on public.reminders
  for select using (public.is_family_pet(pet_id));
create policy reminders_insert_member on public.reminders
  for insert with check (
    (select auth.uid()) = user_id
    and public.is_family_pet(pet_id)
  );
create policy reminders_update_owner on public.reminders
  for update using ((select auth.uid()) = user_id)
                with check ((select auth.uid()) = user_id);
create policy reminders_delete_owner on public.reminders
  for delete using ((select auth.uid()) = user_id);

-- analysis_feedback is INTENTIONALLY kept owner-only (per-user perception
-- signal, not family-shared) — the Phase 1.1 policy still applies.
-- referrals: ditto (per-user reward pool, not family-shared).

comment on table  public.family_groups   is 'Phase 6.3 — a "household". Every user has at least one solo group (auto-created on signup).';
comment on table  public.family_members  is 'Phase 6.3 — many-users-to-one-group membership. RLS bypass via is_family_member().';
comment on column public.pets.family_group_id is 'Phase 6.3 — the group this pet is shared with. Defaults to the owner''s solo group via a BEFORE INSERT trigger.';
