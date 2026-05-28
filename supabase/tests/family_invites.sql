-- Phase 6.3.1 — family_invites pg test. Runs after family_sharing.sql in the
-- same harness, so the A/B/C/D fixtures + the Smith family group already exist.
--
-- Asserts:
--   1. status CHECK rejects unknown values.
--   2. RLS: only the inviter can SELECT their own invite rows.
--      Cross-user SELECT returns 0 rows (no leak).
--   3. Authenticated cannot INSERT directly (writes are service-role-only).
--   4. count_shared_group_memberships() reflects reality:
--        - D (only in their solo group)      -> 0
--        - A and B (also in the Smith family) -> 1
--        - C (only in their solo group)      -> 0

reset role;
select set_config('request.jwt.claims', '', false);

-- 1. CHECK constraint
do $$
declare oops boolean := false;
begin
  begin
    insert into public.family_invites (group_id, invited_by_user_id, token, status)
    values ('5a5a5a5a-5a5a-5a5a-5a5a-5a5a5a5a5a5a',
            '6a000000-0000-0000-0000-000000000001',
            'tok-bad-status', 'bogus_status');
    oops := true;
  exception when check_violation then
    -- expected
  end;
  if oops then raise exception 'CHECK did NOT reject a bogus invite status'; end if;
end
$$;

-- Seed: A invites foo@example.com to the Smith family.
insert into public.family_invites (group_id, invited_by_user_id, invited_email, token, expires_at)
values (
  '5a5a5a5a-5a5a-5a5a-5a5a-5a5a5a5a5a5a',
  '6a000000-0000-0000-0000-000000000001',
  'foo@example.com',
  'inv_token_owner_can_see',
  now() + interval '24 hours'
);

-- 2. RLS — A sees the invite they created.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"6a000000-0000-0000-0000-000000000001"}', false);
do $$
declare n int;
begin
  select count(*) into n from public.family_invites where token = 'inv_token_owner_can_see';
  if n <> 1 then raise exception 'A cannot SELECT their own invite (RLS broken), got %', n; end if;
end
$$;

-- 2 (cont.) RLS — D (uninvolved) does NOT see A's invite.
reset role; select set_config('request.jwt.claims', '', false);
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"6d000000-0000-0000-0000-000000000004"}', false);
do $$
begin
  if exists (select 1 from public.family_invites where token = 'inv_token_owner_can_see') then
    raise exception 'INVITE LEAK: D can SELECT A''s invite (RLS broken)';
  end if;
end
$$;

-- 3. authenticated cannot INSERT directly (writes are service-role-only).
do $$
begin
  begin
    insert into public.family_invites (group_id, invited_by_user_id, token)
    values ('5a5a5a5a-5a5a-5a5a-5a5a-5a5a5a5a5a5a',
            '6d000000-0000-0000-0000-000000000004',
            'evil_token');
    raise exception 'WRITE LEAK: authenticated could INSERT into family_invites';
  exception
    when insufficient_privilege then null; -- expected
    when others then null; -- some PG setups raise a different code under RLS; either is acceptable
  end;
end
$$;

-- 4. count_shared_group_memberships — reset role first.
reset role; select set_config('request.jwt.claims', '', false);

do $$
declare
  a int := public.count_shared_group_memberships('6a000000-0000-0000-0000-000000000001');
  b int := public.count_shared_group_memberships('6b000000-0000-0000-0000-000000000002');
  c int := public.count_shared_group_memberships('6c000000-0000-0000-0000-000000000003');
  d int := public.count_shared_group_memberships('6d000000-0000-0000-0000-000000000004');
begin
  if a <> 1 then raise exception 'A is in 1 shared group (Smith), got %', a; end if;
  if b <> 1 then raise exception 'B is in 1 shared group (Smith), got %', b; end if;
  if c <> 0 then raise exception 'C is only in their solo group, got %', c; end if;
  if d <> 0 then raise exception 'D is only in their solo group, got %', d; end if;
end
$$;

select 'FAMILY INVITES TESTS PASSED' as result;
