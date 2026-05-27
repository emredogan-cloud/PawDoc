-- 72h follow-up eligibility test (Phase 4.1). Proves pending_followup_analyses()
-- returns exactly the caller's analyses older than 72h with NO feedback — and,
-- because it is SECURITY INVOKER under RLS, never another user's. Seeded as the
-- owner; the RPC is then called acting as authenticated user A. Any violation
-- RAISEs (psql ON_ERROR_STOP -> non-zero).

-- authenticated needs to call the RPC + read the tables it touches.
grant usage on schema public, auth to authenticated;
grant execute on function auth.uid() to authenticated;

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test'),
  ('22222222-2222-2222-2222-222222222222', 'b@test');
insert into public.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test'),
  ('22222222-2222-2222-2222-222222222222', 'b@test');
insert into public.pets (id, user_id, name, species) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Rex',  'dog'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'Milo', 'cat');

-- A: old + no feedback (ELIGIBLE); old + has feedback (not); recent (not).
-- B: old + no feedback (cross-user, must be invisible to A).
insert into public.analyses (id, user_id, pet_id, input_type, triage_level, created_at) values
  ('f1000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'text', 'MONITOR', now() - interval '100 hours'),
  ('f2000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'text', 'NORMAL',  now() - interval '100 hours'),
  ('f3000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'text', 'NORMAL',  now() - interval '1 hour'),
  ('f4000000-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'text', 'MONITOR', now() - interval '100 hours');

-- f2 already has feedback -> excluded.
insert into public.analysis_feedback (analysis_id, rating) values
  ('f2000000-0000-0000-0000-000000000002', 5);

-- Act as authenticated user A.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111"}', false);

do $$
declare ids uuid[];
begin
  select array_agg(id) into ids from public.pending_followup_analyses();
  if coalesce(array_length(ids, 1), 0) <> 1 then
    raise exception 'eligibility expected exactly 1 analysis, got %', coalesce(array_length(ids, 1), 0);
  end if;
  if ids[1] <> 'f1000000-0000-0000-0000-000000000001' then
    raise exception 'eligibility returned the wrong analysis: %', ids[1];
  end if;
  -- explicit exclusions (defensive)
  if ids @> array['f2000000-0000-0000-0000-000000000002']::uuid[] then raise exception 'analysis WITH feedback should be excluded'; end if;
  if ids @> array['f3000000-0000-0000-0000-000000000003']::uuid[] then raise exception 'recent analysis (<72h) should be excluded'; end if;
  if ids @> array['f4000000-0000-0000-0000-000000000004']::uuid[] then raise exception 'CROSS-USER LEAK: B''s analysis returned to A'; end if;
end
$$;

reset role;
select 'FOLLOW-UP ELIGIBILITY TESTS PASSED' as result;
