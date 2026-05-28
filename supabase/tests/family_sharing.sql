-- Phase 6.3 — Family Sharing RLS test (the highest-risk migration).
-- This test runs AFTER rls_isolation.sql + account_deletion.sql in the
-- same psql session, so it uses disjoint UUIDs (6a..6d) to avoid colliding
-- with the legacy fixtures.
--
-- Scenario:
--   * Three users: A, B, C; plus a standalone D.
--   * A creates a pet (Rex) — auto-defaults to A's solo family group.
--   * A creates a SHARED group, adds B as a member.
--   * A moves Rex into the SHARED group.
--   * C joins NO group beyond their own solo group.
--   * D never joins any shared group — proves solo-group default works.
--
-- Assertions:
--   1. A SEES Rex.
--   2. B SEES Rex (via shared group).                                   <-- the core deliverable
--   3. C does NOT see Rex.                                              <-- safety
--   4. B can INSERT an analysis on Rex (any family member can log).
--   5. C cannot INSERT an analysis on Rex.
--   6. B cannot UPDATE Rex (UPDATE is owner-only).
--   7. B cannot DELETE an analysis A created (DELETE is owner-only).
--   8. D's standalone pet is invisible to A/B/C, visible to D.
--   9. A standalone user is auto-given a solo group by the trigger.

grant usage on schema public, auth, extensions to authenticated;
grant execute on function auth.uid() to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on function public.is_family_member(uuid) to authenticated;
grant execute on function public.is_family_pet(uuid)    to authenticated;

-- Fixtures (seeded as the owner — RLS bypass).
insert into auth.users (id, email) values
  ('6a000000-0000-0000-0000-000000000001', 'fa@test'),
  ('6b000000-0000-0000-0000-000000000002', 'fb@test'),
  ('6c000000-0000-0000-0000-000000000003', 'fc@test'),
  ('6d000000-0000-0000-0000-000000000004', 'fd@test');

-- Inserting into public.users fires the create_solo_family_for_new_user
-- trigger → each user automatically has a solo family_group + membership.
insert into public.users (id, email) values
  ('6a000000-0000-0000-0000-000000000001', 'fa@test'),
  ('6b000000-0000-0000-0000-000000000002', 'fb@test'),
  ('6c000000-0000-0000-0000-000000000003', 'fc@test'),
  ('6d000000-0000-0000-0000-000000000004', 'fd@test');

-- Assert 9: trigger created solo groups for all four (one each).
do $$
declare n int;
begin
  select count(*) into n
  from public.family_members
  where user_id in (
    '6a000000-0000-0000-0000-000000000001',
    '6b000000-0000-0000-0000-000000000002',
    '6c000000-0000-0000-0000-000000000003',
    '6d000000-0000-0000-0000-000000000004'
  ) and role = 'owner';
  if n <> 4 then
    raise exception 'solo-group trigger should have created 4 owner memberships, got %', n;
  end if;
end
$$;

-- A creates a SHARED group, adds B.
insert into public.family_groups (id, owner_user_id, name) values
  ('5a5a5a5a-5a5a-5a5a-5a5a-5a5a5a5a5a5a', '6a000000-0000-0000-0000-000000000001', 'Smith family');
insert into public.family_members (group_id, user_id, role) values
  ('5a5a5a5a-5a5a-5a5a-5a5a-5a5a5a5a5a5a', '6a000000-0000-0000-0000-000000000001', 'owner'),
  ('5a5a5a5a-5a5a-5a5a-5a5a-5a5a5a5a5a5a', '6b000000-0000-0000-0000-000000000002', 'member');

-- A creates Rex (the BEFORE INSERT trigger defaults him to A's solo group)
-- and then moves him to the SHARED group. This proves the family_group_id
-- migration path AND the default trigger work end-to-end.
insert into public.pets (id, user_id, name, species) values
  ('6abce700-0000-0000-0000-000000000001', '6a000000-0000-0000-0000-000000000001', 'Rex', 'dog');
update public.pets
set family_group_id = '5a5a5a5a-5a5a-5a5a-5a5a-5a5a5a5a5a5a'
where id = '6abce700-0000-0000-0000-000000000001';

-- A's analysis on Rex.
insert into public.analyses (id, user_id, pet_id, input_type, triage_level) values
  ('6aa10000-0000-0000-0000-000000000001', '6a000000-0000-0000-0000-000000000001', '6abce700-0000-0000-0000-000000000001', 'text', 'NORMAL');

-- D's standalone pet (lives in D's solo group; only D ever sees it).
insert into public.pets (id, user_id, name, species) values
  ('6d501000-0000-0000-0000-000000000001', '6d000000-0000-0000-0000-000000000004', 'SoloDog', 'dog');

-- =============================================================
-- ASSERTIONS — switch role for each user, check what they see.
-- =============================================================

-- ASSERT 1: A sees Rex.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"6a000000-0000-0000-0000-000000000001"}', false);
do $$
begin
  if not exists (
    select 1 from public.pets where id = '6abce700-0000-0000-0000-000000000001'
  ) then raise exception 'A cannot see Rex (own pet, shared group)'; end if;
end
$$;

-- ASSERT 2: B sees Rex via the shared group.
reset role; select set_config('request.jwt.claims', '', false);
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"6b000000-0000-0000-0000-000000000002"}', false);
do $$
begin
  if not exists (
    select 1 from public.pets where id = '6abce700-0000-0000-0000-000000000001'
  ) then raise exception 'B cannot see Rex via shared family_group (SHARING IS BROKEN)'; end if;
  if not exists (
    select 1 from public.analyses where pet_id = '6abce700-0000-0000-0000-000000000001'
  ) then raise exception 'B cannot see A''s analyses on Rex'; end if;
end
$$;

-- ASSERT 4: B can INSERT an analysis on Rex (any family member can log).
insert into public.analyses (id, user_id, pet_id, input_type, triage_level) values
  ('6bb10000-0000-0000-0000-000000000002', '6b000000-0000-0000-0000-000000000002', '6abce700-0000-0000-0000-000000000001', 'text', 'MONITOR');

-- ASSERT 4 (cont.): B can INSERT a health_event on Rex (no user_id col → group-wide).
insert into public.health_events (pet_id, event_type, event_date, notes) values
  ('6abce700-0000-0000-0000-000000000001', 'weight', current_date, 'logged by B');

-- ASSERT 6: B cannot UPDATE Rex (UPDATE is owner-only).
do $$
begin
  update public.pets set name = 'Hijack' where id = '6abce700-0000-0000-0000-000000000001';
  if found then
    raise exception 'B was able to UPDATE A''s pet (owner-only rule failed)';
  end if;
end
$$;

-- ASSERT 7: B cannot DELETE A's analysis (DELETE is owner-only).
do $$
begin
  delete from public.analyses where id = '6aa10000-0000-0000-0000-000000000001';
  if found then
    raise exception 'B was able to DELETE A''s analysis (owner-only rule failed)';
  end if;
end
$$;

-- ASSERT 3: C does NOT see Rex.
reset role; select set_config('request.jwt.claims', '', false);
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"6c000000-0000-0000-0000-000000000003"}', false);
do $$
begin
  if exists (
    select 1 from public.pets where id = '6abce700-0000-0000-0000-000000000001'
  ) then raise exception 'C sees Rex (CROSS-FAMILY LEAK — SECURITY HOLE)'; end if;
  if exists (
    select 1 from public.analyses where pet_id = '6abce700-0000-0000-0000-000000000001'
  ) then raise exception 'C sees analyses on Rex (CROSS-FAMILY LEAK)'; end if;
  if exists (
    select 1 from public.health_events where pet_id = '6abce700-0000-0000-0000-000000000001'
  ) then raise exception 'C sees health_events on Rex (CROSS-FAMILY LEAK)'; end if;
end
$$;

-- ASSERT 5: C cannot INSERT an analysis on Rex (WITH CHECK blocks via family).
do $$
begin
  begin
    insert into public.analyses (id, user_id, pet_id, input_type, triage_level) values
      ('6cc10000-0000-0000-0000-000000000001', '6c000000-0000-0000-0000-000000000003',
       '6abce700-0000-0000-0000-000000000001', 'text', 'NORMAL');
    raise exception 'C was able to INSERT an analysis on Rex (CROSS-FAMILY WRITE LEAK)';
  exception when insufficient_privilege then null; -- expected
  end;
end
$$;

-- ASSERT 5 (cont.): C cannot INSERT a health_event on Rex.
do $$
begin
  begin
    insert into public.health_events (pet_id, event_type, event_date, notes) values
      ('6abce700-0000-0000-0000-000000000001', 'weight', current_date, 'hijack by C');
    raise exception 'C was able to INSERT a health_event on Rex (CROSS-FAMILY WRITE LEAK)';
  exception when insufficient_privilege then null; -- expected
  end;
end
$$;

-- ASSERT 8: D's standalone pet is invisible to A, visible to D.
reset role; select set_config('request.jwt.claims', '', false);
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"6a000000-0000-0000-0000-000000000001"}', false);
do $$
begin
  if exists (select 1 from public.pets where id = '6d501000-0000-0000-0000-000000000001') then
    raise exception 'A can see D''s standalone pet (SOLO-GROUP ISOLATION BROKEN)';
  end if;
end
$$;

reset role; select set_config('request.jwt.claims', '', false);
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"6d000000-0000-0000-0000-000000000004"}', false);
do $$
begin
  if not exists (select 1 from public.pets where id = '6d501000-0000-0000-0000-000000000001') then
    raise exception 'D cannot see D''s own standalone pet (SOLO-GROUP DEFAULT BROKEN)';
  end if;
end
$$;

reset role;
select set_config('request.jwt.claims', '', false);
select 'FAMILY SHARING RLS TESTS PASSED' as result;
