-- Engagement query-function test (Phase 3.3 Part 2). Proves due_reminders() and
-- users_to_reengage() return exactly the right rows, and that both are locked to
-- the service role. Seeded as the owner; functions run as the superuser. Any
-- violation RAISEs (psql ON_ERROR_STOP -> non-zero).

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'due@test'),
  ('22222222-2222-2222-2222-222222222222', 'noplayer@test'),
  ('33333333-3333-3333-3333-333333333333', 'lapsed@test'),
  ('44444444-4444-4444-4444-444444444444', 'active@test'),
  ('55555555-5555-5555-5555-555555555555', 'cooled@test'),
  ('66666666-6666-6666-6666-666666666666', 'new@test');

insert into public.users (id, email, one_signal_player_id, created_at, last_reengagement_sent_at) values
  ('11111111-1111-1111-1111-111111111111', 'due@test',      'p_due',    now() - interval '60 days', null),
  ('22222222-2222-2222-2222-222222222222', 'noplayer@test',  null,      now() - interval '60 days', null),
  ('33333333-3333-3333-3333-333333333333', 'lapsed@test',   'p_lapsed', now() - interval '60 days', null),
  ('44444444-4444-4444-4444-444444444444', 'active@test',   'p_active', now() - interval '60 days', null),
  ('55555555-5555-5555-5555-555555555555', 'cooled@test',   'p_cooled', now() - interval '60 days', now() - interval '10 days'),
  ('66666666-6666-6666-6666-666666666666', 'new@test',      'p_new',    now() - interval '5 days',  null);

insert into public.pets (id, user_id, name, species) values
  ('d0000000-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'Rex',  'dog'),
  ('d0000000-0000-0000-0000-00000000000b', '22222222-2222-2222-2222-222222222222', 'Milo', 'cat');

-- Reminders for the DUE user: one due-today (fires), one future, one already sent.
insert into public.reminders (id, pet_id, user_id, reminder_type, due_date, is_sent) values
  ('1ee00000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'Flea medication', (now() at time zone 'utc')::date,            false),
  ('1ee00000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'Vet appointment', (now() at time zone 'utc')::date + 10,       false),
  ('1ee00000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'Vaccine',         (now() at time zone 'utc')::date - 5,        true),
  -- Due, but the owner has no push id -> excluded.
  ('1ee00000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-00000000000b', '22222222-2222-2222-2222-222222222222', 'Flea medication', (now() at time zone 'utc')::date,            false);

-- Analyses: ACTIVE has a recent one; LAPSED + COOLED have only old ones; DUE is
-- recently active too (so it does NOT also show up for re-engagement).
insert into public.analyses (user_id, pet_id, input_type, created_at) values
  ('11111111-1111-1111-1111-111111111111', null, 'text', now() - interval '5 days'),
  ('44444444-4444-4444-4444-444444444444', null, 'text', now() - interval '5 days'),
  ('33333333-3333-3333-3333-333333333333', null, 'text', now() - interval '40 days'),
  ('55555555-5555-5555-5555-555555555555', null, 'text', now() - interval '40 days');

-- 1. due_reminders(): exactly the one due+unsent reminder whose owner has a push id.
do $$
declare ids uuid[]; players text[];
begin
  select array_agg(id), array_agg(player_id) into ids, players from public.due_reminders();
  if coalesce(array_length(ids, 1), 0) <> 1 then
    raise exception 'due_reminders expected 1 row, got %', coalesce(array_length(ids, 1), 0);
  end if;
  if ids[1] <> '1ee00000-0000-0000-0000-000000000001' then
    raise exception 'due_reminders returned the wrong reminder: %', ids[1];
  end if;
  if players[1] <> 'p_due' then
    raise exception 'due_reminders returned the wrong player_id: %', players[1];
  end if;
end
$$;

-- 2. users_to_reengage(30, 30): exactly the lapsed user with a push id and no
--    recent analysis / re-engagement.
do $$
declare ids uuid[];
begin
  select array_agg(user_id) into ids from public.users_to_reengage(30, 30);
  if coalesce(array_length(ids, 1), 0) <> 1 then
    raise exception 're-engage expected 1 user, got %', coalesce(array_length(ids, 1), 0);
  end if;
  if ids[1] <> '33333333-3333-3333-3333-333333333333' then
    raise exception 're-engage returned the wrong user: %', ids[1];
  end if;
  -- explicit exclusions (defensive)
  if ids @> array['44444444-4444-4444-4444-444444444444']::uuid[] then raise exception 'active user should not be re-engaged'; end if;
  if ids @> array['55555555-5555-5555-5555-555555555555']::uuid[] then raise exception 'cooled-down user should not be re-engaged'; end if;
  if ids @> array['66666666-6666-6666-6666-666666666666']::uuid[] then raise exception 'brand-new user should not be re-engaged'; end if;
  if ids @> array['22222222-2222-2222-2222-222222222222']::uuid[] then raise exception 'user without a push id should not be re-engaged'; end if;
end
$$;

-- 3. Lockdown: service-role only.
do $$
begin
  if has_function_privilege('authenticated', 'public.due_reminders()', 'execute') then
    raise exception 'LOCKDOWN: authenticated can execute due_reminders';
  end if;
  if has_function_privilege('authenticated', 'public.users_to_reengage(int, int)', 'execute') then
    raise exception 'LOCKDOWN: authenticated can execute users_to_reengage';
  end if;
  if not has_function_privilege('service_role', 'public.due_reminders()', 'execute') then
    raise exception 'service_role should execute due_reminders';
  end if;
  if not has_function_privilege('service_role', 'public.users_to_reengage(int, int)', 'execute') then
    raise exception 'service_role should execute users_to_reengage';
  end if;
end
$$;

select 'REMINDERS ENGAGEMENT TESTS PASSED' as result;
