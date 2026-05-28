-- Phase 5.4 — B2B-Lite (sitter) tier eligibility for the AI Health Journal.
-- Runs AFTER the b2b_lite_journal_eligibility migration has REPLACE'd the RPC
-- and after the health_journals.sql seed (which already inserted A..F). Adds
-- a sitter user G with TWO clients' pets to assert:
--   1. b2b_lite is treated as a premium tier by pets_pending_journal,
--   2. multiple "clients" managed by one sitter all qualify (RLS scopes to G).
--
-- The previous test set the role to authenticated; reset back to owner first.
reset role;
select set_config('request.jwt.claims', '', false);

insert into auth.users (id, email) values
  ('aa000000-0000-0000-0000-000000000007', 'sitter@test');

insert into public.users (id, email, subscription_status) values
  ('aa000000-0000-0000-0000-000000000007', 'sitter@test', 'b2b_lite');

insert into public.pets (id, user_id, name, species, is_journal_enabled, client_name) values
  ('a7000000-0000-0000-0000-000000000071', 'aa000000-0000-0000-0000-000000000007', 'Coco',  'dog',    true, 'Smith family'),
  ('a7000000-0000-0000-0000-000000000072', 'aa000000-0000-0000-0000-000000000007', 'Bunny', 'rabbit', true, 'Jones family');

do $$
declare ids uuid[];
begin
  select array_agg(pet_id) into ids from public.pets_pending_journal(date '2026-05-25');
  if not (ids @> array[
       'a7000000-0000-0000-0000-000000000071',
       'a7000000-0000-0000-0000-000000000072']::uuid[]) then
    raise exception 'B2B-LITE LEAK: sitter pets not returned by eligibility RPC: %', ids;
  end if;
end
$$;

-- Confirm client_name survived the migration + insert.
do $$
declare n int;
begin
  select count(*) into n
  from public.pets
  where user_id = 'aa000000-0000-0000-0000-000000000007'
    and client_name in ('Smith family', 'Jones family');
  if n <> 2 then raise exception 'client_name round-trip lost: %', n; end if;
end
$$;

select 'B2B-LITE JOURNAL TESTS PASSED' as result;
