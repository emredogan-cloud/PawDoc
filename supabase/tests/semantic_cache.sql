-- Semantic-cache safety test (Phase 3.2). Proves match_analyses() respects the
-- hard guarantees: same-user, same-species (Dog never matches Bird), NULL
-- embeddings ignored, similarity threshold enforced, and the RPC is locked to
-- the service role. Seeded as the table owner (RLS bypassed for fixtures);
-- match_analyses is called as the superuser, which bypasses the GRANT (the
-- lockdown is asserted separately via has_function_privilege). Any violation
-- RAISEs, so psql (ON_ERROR_STOP) exits non-zero.

-- Build a 1536-dim vector with the given {index: value} non-zero entries, 0 else.
create or replace function pg_temp.mkvec(nonzero jsonb) returns extensions.vector
language sql as $$
  select ('[' || string_agg(coalesce(nonzero ->> (g::text), '0'), ',' order by g) || ']')::extensions.vector
  from generate_series(1, 1536) g;
$$;

-- Fixtures.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test'),
  ('22222222-2222-2222-2222-222222222222', 'b@test');
insert into public.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test'),
  ('22222222-2222-2222-2222-222222222222', 'b@test');
insert into public.pets (id, user_id, name, species) values
  ('d0000000-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'Rex',  'dog'),
  ('b0000000-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'Tweety','bird'),
  ('d0000000-0000-0000-0000-00000000000b', '22222222-2222-2222-2222-222222222222', 'Spot', 'dog');

-- A1: user A, DOG, embedding one-hot@1 (the reference).
-- A2: user A, BIRD, embedding ALSO one-hot@1 — i.e. embedding-identical to A1.
--     If the species guard were missing, a dog query would match this bird.
-- A3: user A, DOG, NULL embedding (historical row) — must be ignored.
-- B1: user B, DOG, embedding one-hot@1 — must never reach user A.
insert into public.analyses (id, user_id, pet_id, input_type, triage_level, confidence_score, full_response, embedding) values
  ('a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'd0000000-0000-0000-0000-00000000000a', 'text', 'NORMAL', 0.90, '{"triage_level":"NORMAL"}', pg_temp.mkvec('{"1":"1"}')),
  ('a2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'b0000000-0000-0000-0000-00000000000a', 'text', 'NORMAL', 0.90, '{"triage_level":"NORMAL"}', pg_temp.mkvec('{"1":"1"}')),
  ('a3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'd0000000-0000-0000-0000-00000000000a', 'text', 'NORMAL', 0.90, '{"triage_level":"NORMAL"}', null),
  ('b1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'd0000000-0000-0000-0000-00000000000b', 'text', 'NORMAL', 0.90, '{"triage_level":"NORMAL"}', pg_temp.mkvec('{"1":"1"}'));

-- A query vector ~0.99 cosine-similar to one-hot@1 (>= 0.90 threshold).
-- 1) Positive: exactly ONE match for (user A, dog) = A1. That n=1 also proves
--    the bird (A2), the other user (B1) and the NULL row (A3) are all excluded.
do $$
declare ids uuid[];
begin
  select array_agg(id) into ids
  from public.match_analyses(pg_temp.mkvec('{"1":"0.99","2":"0.14"}'),
       '11111111-1111-1111-1111-111111111111', 'dog', 0.90, 5);
  if coalesce(array_length(ids, 1), 0) <> 1 then
    raise exception 'expected exactly 1 dog match for user A, got %', coalesce(array_length(ids, 1), 0);
  end if;
  if ids[1] <> 'a1111111-1111-1111-1111-111111111111' then
    raise exception 'wrong row returned: %', ids[1];
  end if;
end
$$;

-- 2) Species guard: query species 'bird' returns the BIRD (A2) and NEVER the
--    DOG (A1), even though A1 is equally embedding-similar.
do $$
declare ids uuid[];
begin
  select array_agg(id) into ids
  from public.match_analyses(pg_temp.mkvec('{"1":"0.99","2":"0.14"}'),
       '11111111-1111-1111-1111-111111111111', 'bird', 0.90, 5);
  if not (ids @> array['a2222222-2222-2222-2222-222222222222']::uuid[]) then
    raise exception 'bird query should return the bird analysis (A2)';
  end if;
  if ids @> array['a1111111-1111-1111-1111-111111111111']::uuid[] then
    raise exception 'SPECIES LEAK: dog analysis returned for a bird query';
  end if;
end
$$;

-- 3) Cross-user: user B''s identical-embedding dog is never returned to A.
do $$
declare ids uuid[];
begin
  select array_agg(id) into ids
  from public.match_analyses(pg_temp.mkvec('{"1":"1"}'),
       '11111111-1111-1111-1111-111111111111', 'dog', 0.90, 5);
  if ids @> array['b1111111-1111-1111-1111-111111111111']::uuid[] then
    raise exception 'CROSS-USER LEAK: user B analysis returned to user A';
  end if;
end
$$;

-- 4) Threshold: a dissimilar query returns nothing (no weak matches served).
do $$
declare n int;
begin
  select count(*) into n
  from public.match_analyses(pg_temp.mkvec('{"50":"1"}'),
       '11111111-1111-1111-1111-111111111111', 'dog', 0.90, 5);
  if n <> 0 then raise exception 'dissimilar query should return 0 rows, got %', n; end if;
end
$$;

-- 5) Lockdown: anon/authenticated must NOT have EXECUTE; service_role must.
do $$
begin
  if has_function_privilege('authenticated',
       'public.match_analyses(extensions.vector, uuid, text, double precision, integer)', 'execute') then
    raise exception 'LOCKDOWN FAILED: authenticated can execute match_analyses';
  end if;
  if has_function_privilege('anon',
       'public.match_analyses(extensions.vector, uuid, text, double precision, integer)', 'execute') then
    raise exception 'LOCKDOWN FAILED: anon can execute match_analyses';
  end if;
  if not has_function_privilege('service_role',
       'public.match_analyses(extensions.vector, uuid, text, double precision, integer)', 'execute') then
    raise exception 'service_role should be able to execute match_analyses';
  end if;
end
$$;

select 'SEMANTIC CACHE TESTS PASSED' as result;
