-- Phase 5.3 — health_journals + pets_pending_journal pg test.
-- Proves: tier+opt-in+idempotency filter, per-user RLS row visibility, RPC + table
-- lockdowns. Seeded as the owner; the authenticated SELECT is exercised under RLS.

-- A: premium opt-in (eligible)        — also has an OLDER journal for visibility test
-- B: free opt-in (NOT eligible — free)
-- C: premium opt-OUT (NOT eligible)
-- D: premium opt-in BUT already journaled this week (NOT eligible — idempotency)
-- E: family opt-in (eligible)
-- F: trial  opt-in (eligible)
insert into auth.users (id, email) values
  ('aa000000-0000-0000-0000-000000000001', 'a@test'),
  ('bb000000-0000-0000-0000-000000000002', 'b@test'),
  ('cc000000-0000-0000-0000-000000000003', 'c@test'),
  ('dd000000-0000-0000-0000-000000000004', 'd@test'),
  ('ee000000-0000-0000-0000-000000000005', 'e@test'),
  ('ff000000-0000-0000-0000-000000000006', 'f@test');

insert into public.users (id, email, subscription_status) values
  ('aa000000-0000-0000-0000-000000000001', 'a@test', 'premium'),
  ('bb000000-0000-0000-0000-000000000002', 'b@test', 'free'),
  ('cc000000-0000-0000-0000-000000000003', 'c@test', 'premium'),
  ('dd000000-0000-0000-0000-000000000004', 'd@test', 'premium'),
  ('ee000000-0000-0000-0000-000000000005', 'e@test', 'family'),
  ('ff000000-0000-0000-0000-000000000006', 'f@test', 'trial');

insert into public.pets (id, user_id, name, species, is_journal_enabled) values
  ('aa000000-0000-0000-0000-0000000000a1', 'aa000000-0000-0000-0000-000000000001', 'Rex',    'dog',    true),
  ('bb000000-0000-0000-0000-0000000000b1', 'bb000000-0000-0000-0000-000000000002', 'Milo',   'cat',    true),
  ('cc000000-0000-0000-0000-0000000000c1', 'cc000000-0000-0000-0000-000000000003', 'OptOut', 'dog',    false),
  ('dd000000-0000-0000-0000-0000000000d1', 'dd000000-0000-0000-0000-000000000004', 'Done',   'dog',    true),
  ('ee000000-0000-0000-0000-0000000000e1', 'ee000000-0000-0000-0000-000000000005', 'Lily',   'rabbit', true),
  ('ff000000-0000-0000-0000-0000000000f1', 'ff000000-0000-0000-0000-000000000006', 'Buddy',  'dog',    true);

-- A: older journal (visibility test).
-- D: journal for the TARGET week (idempotency: must keep D out of the RPC result).
-- B: own journal (must NOT leak to A under RLS).
insert into public.health_journals (pet_id, user_id, narrative_text, week_start_date) values
  ('aa000000-0000-0000-0000-0000000000a1', 'aa000000-0000-0000-0000-000000000001', 'older A narrative', date '2026-05-18'),
  ('dd000000-0000-0000-0000-0000000000d1', 'dd000000-0000-0000-0000-000000000004', 'D done this week',  date '2026-05-25'),
  ('bb000000-0000-0000-0000-0000000000b1', 'bb000000-0000-0000-0000-000000000002', 'B narrative',       date '2026-05-18');

-- 1. Eligibility: returns A, E, F for week 2026-05-25.
do $$
declare ids uuid[];
begin
  select array_agg(pet_id) into ids from public.pets_pending_journal(date '2026-05-25');
  if coalesce(array_length(ids, 1), 0) <> 3 then
    raise exception 'eligibility expected 3 pets, got %', coalesce(array_length(ids, 1), 0);
  end if;
  if not (ids @> array[
       'aa000000-0000-0000-0000-0000000000a1',
       'ee000000-0000-0000-0000-0000000000e1',
       'ff000000-0000-0000-0000-0000000000f1']::uuid[]) then
    raise exception 'wrong eligibility set: %', ids;
  end if;
  if ids @> array['bb000000-0000-0000-0000-0000000000b1']::uuid[] then
    raise exception 'TIER LEAK: free-tier pet returned';
  end if;
  if ids @> array['cc000000-0000-0000-0000-0000000000c1']::uuid[] then
    raise exception 'OPT-OUT LEAK: opted-out pet returned';
  end if;
  if ids @> array['dd000000-0000-0000-0000-0000000000d1']::uuid[] then
    raise exception 'IDEMPOTENCY LEAK: already-journaled pet returned';
  end if;
end
$$;

-- 2. Per-user RLS visibility: as authenticated A, only A's journal is visible.
grant usage on schema public, auth to authenticated;
grant execute on function auth.uid() to authenticated;

set role authenticated;
select set_config('request.jwt.claims', '{"sub":"aa000000-0000-0000-0000-000000000001"}', false);

do $$
declare n int;
begin
  select count(*) into n from public.health_journals;
  if n <> 1 then raise exception 'A should see exactly 1 journal (own), got %', n; end if;
  if not exists (select 1 from public.health_journals
                 where user_id = 'aa000000-0000-0000-0000-000000000001') then
    raise exception 'A''s journal not visible';
  end if;
end
$$;

reset role;

-- 3. Lockdowns
do $$
begin
  if has_function_privilege('authenticated', 'public.pets_pending_journal(date)', 'execute') then
    raise exception 'LOCKDOWN: authenticated can execute pets_pending_journal';
  end if;
  if not has_function_privilege('service_role', 'public.pets_pending_journal(date)', 'execute') then
    raise exception 'service_role should execute pets_pending_journal';
  end if;
  if has_table_privilege('authenticated', 'public.health_journals', 'INSERT') then
    raise exception 'LOCKDOWN: authenticated can INSERT health_journals';
  end if;
  if not has_table_privilege('authenticated', 'public.health_journals', 'SELECT') then
    raise exception 'authenticated should retain SELECT on health_journals (RLS gates rows)';
  end if;
end
$$;

select 'HEALTH JOURNAL TESTS PASSED' as result;
