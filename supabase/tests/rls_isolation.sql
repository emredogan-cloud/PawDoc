-- RLS isolation test (verifies the CR #2 correction).
-- Run after the schema + RLS migrations against the local harness
-- (scripts/test-rls.sh). Asserts that an authenticated user A can neither READ
-- nor WRITE user B's rows, across pets / analyses / health_events.
-- Any violation RAISEs, so psql (ON_ERROR_STOP) exits non-zero.

-- Privileges (RLS still governs which ROWS are visible/insertable).
grant usage on schema public, auth, extensions to authenticated;
grant execute on function auth.uid() to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- Fixtures (seeded as the table owner, so RLS is bypassed here).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test'),
  ('22222222-2222-2222-2222-222222222222', 'b@test');
insert into public.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test'),
  ('22222222-2222-2222-2222-222222222222', 'b@test');
insert into public.pets (id, user_id, name, species) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Rex', 'dog'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'Milo', 'cat');
insert into public.analyses (id, user_id, pet_id, input_type) values
  ('a1a1a1a1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'text'),
  ('b1b1b1b1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'text');
insert into public.health_events (pet_id, event_type, event_date) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'weight', current_date),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'weight', current_date);

-- Act as authenticated user A.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);

-- READ isolation across the three tables.
do $$
begin
  if (select count(*) from public.pets) <> 1 then
    raise exception 'pets READ: A sees % rows, expected 1', (select count(*) from public.pets);
  end if;
  if exists (select 1 from public.pets where user_id = '22222222-2222-2222-2222-222222222222') then
    raise exception 'pets READ: A can see B''s pet';
  end if;
  if (select count(*) from public.analyses) <> 1 then
    raise exception 'analyses READ: A sees % rows, expected 1', (select count(*) from public.analyses);
  end if;
  if (select count(*) from public.health_events) <> 1 then
    raise exception 'health_events READ: A sees % rows, expected 1', (select count(*) from public.health_events);
  end if;
end
$$;

-- WRITE isolation: A must NOT insert a pet owned by B (WITH CHECK).
do $$
begin
  begin
    insert into public.pets (user_id, name, species)
    values ('22222222-2222-2222-2222-222222222222', 'Hijack', 'dog');
    raise exception 'pets WRITE: A inserted a row for B (RLS WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected: row violates RLS policy
  end;
end
$$;

-- WRITE isolation via parent: A must NOT add a health_event to B's pet.
do $$
begin
  begin
    insert into public.health_events (pet_id, event_type, event_date)
    values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'weight', current_date);
    raise exception 'health_events WRITE: A wrote to B''s pet (RLS WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Positive control: A CAN insert its own pet.
insert into public.pets (user_id, name, species)
values ('11111111-1111-1111-1111-111111111111', 'Buddy', 'dog');
do $$
begin
  if (select count(*) from public.pets) <> 2 then
    raise exception 'pets WRITE: A should see 2 of its own pets after insert';
  end if;
end
$$;

-- Positive control (CR #2 + Phase 3.1 manual quick-add): A CAN insert a
-- health_event for ITS OWN pet. health_events has no user_id column — the RLS
-- WITH CHECK derives ownership from the parent pet (pet_id -> pets.user_id).
-- This proves the manual health-event logging actually works in production.
insert into public.health_events (pet_id, event_type, event_date, notes)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'vaccination', current_date, 'Rabies booster');
do $$
begin
  if (select count(*) from public.health_events) <> 2 then
    raise exception 'health_events WRITE: A own-pet insert blocked (sees % of its events, expected 2)',
      (select count(*) from public.health_events);
  end if;
  if not exists (
    select 1 from public.health_events
    where pet_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and event_type = 'vaccination'
  ) then
    raise exception 'health_events WRITE: A''s own health_event insert did not persist';
  end if;
end
$$;

-- Reminders WRITE isolation (Phase 3.3): A must NOT create a reminder owned by B.
do $$
begin
  begin
    insert into public.reminders (pet_id, user_id, reminder_type, due_date)
    values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'Hijack', current_date);
    raise exception 'reminders WRITE: A inserted a reminder for B (RLS WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Positive control (Phase 3.3): A CAN create its own reminder (the client writes
-- reminders directly, RLS-scoped by user_id). Proves the reminders CRUD works.
insert into public.reminders (pet_id, user_id, reminder_type, due_date)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Flea medication', current_date + 7);
do $$
begin
  if (select count(*) from public.reminders) <> 1 then
    raise exception 'reminders WRITE: A should see exactly its own 1 reminder after insert';
  end if;
end
$$;

-- analysis_feedback WRITE isolation (CR #2 / Phase 4.1): A must NOT submit
-- feedback on B's analysis. Ownership is derived from the parent analysis.
do $$
begin
  begin
    insert into public.analysis_feedback (analysis_id, rating, comment)
    values ('b1b1b1b1-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 1, 'hijack');
    raise exception 'analysis_feedback WRITE: A wrote feedback on B''s analysis (RLS WITH CHECK failed)';
  exception
    when insufficient_privilege then null; -- expected
  end;
end
$$;

-- Positive control (Phase 4.1): A CAN submit feedback on its OWN analysis.
insert into public.analysis_feedback (analysis_id, rating, comment)
values ('a1a1a1a1-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 5, 'helpful');
do $$
begin
  if (select count(*) from public.analysis_feedback) <> 1 then
    raise exception 'analysis_feedback WRITE: A should see exactly its own 1 feedback row';
  end if;
end
$$;

reset role;
select 'RLS ISOLATION TESTS PASSED' as result;
