-- Referral fraud-control test (Phase 3.3). Proves claim_referral():
--   * grants the reward to BOTH sides exactly once on success,
--   * blocks a self-referral, a double-claim, and an invalid code,
--   * and that the lockdowns hold (RPC service-role-only; referrals not
--     client-writable; sensitive users columns not client-updatable).
-- Seeded as the table owner (RLS bypassed); the RPC is SECURITY DEFINER and run
-- here as the superuser. Any violation RAISEs (psql ON_ERROR_STOP -> non-zero).

insert into auth.users (id, email) values
  ('a1111111-1111-1111-1111-111111111111', 'referrer@test'),
  ('b2222222-2222-2222-2222-222222222222', 'claimer@test'),
  ('c3333333-3333-3333-3333-333333333333', 'selfref@test'),
  ('d4444444-4444-4444-4444-444444444444', 'invalid@test');
-- Explicit referral_code (the BEFORE INSERT trigger only fills NULLs).
insert into public.users (id, email, referral_code) values
  ('a1111111-1111-1111-1111-111111111111', 'referrer@test', 'AAAACODE'),
  ('b2222222-2222-2222-2222-222222222222', 'claimer@test',  'BBBBCODE'),
  ('c3333333-3333-3333-3333-333333333333', 'selfref@test',  'CCCCCODE'),
  ('d4444444-4444-4444-4444-444444444444', 'invalid@test',  'DDDDCODE');

-- 1. Success: B claims A's code (lowercase to prove trim/upper-normalization).
do $$
declare r text;
begin
  r := public.claim_referral('b2222222-2222-2222-2222-222222222222', '  aaaacode ');
  if r <> 'success' then raise exception 'expected success, got %', r; end if;
  if (select referred_by_user_id from public.users where id = 'b2222222-2222-2222-2222-222222222222')
       <> 'a1111111-1111-1111-1111-111111111111' then
    raise exception 'claimer referred_by not set to referrer';
  end if;
  if (select bonus_analyses from public.users where id = 'a1111111-1111-1111-1111-111111111111') <> 3 then
    raise exception 'referrer bonus not granted';
  end if;
  if (select bonus_analyses from public.users where id = 'b2222222-2222-2222-2222-222222222222') <> 3 then
    raise exception 'claimer bonus not granted';
  end if;
  if not exists (
    select 1 from public.referrals
    where referrer_user_id = 'a1111111-1111-1111-1111-111111111111'
      and referred_user_id = 'b2222222-2222-2222-2222-222222222222' and converted
  ) then
    raise exception 'no converted referral row recorded';
  end if;
end
$$;

-- 2. Double-claim: B tries again -> already_claimed, NO extra reward.
do $$
declare r text;
begin
  r := public.claim_referral('b2222222-2222-2222-2222-222222222222', 'AAAACODE');
  if r <> 'already_claimed' then raise exception 'expected already_claimed, got %', r; end if;
  if (select bonus_analyses from public.users where id = 'a1111111-1111-1111-1111-111111111111') <> 3 then
    raise exception 'DOUBLE-CLAIM LEAK: referrer bonus changed on a repeat claim';
  end if;
  if (select bonus_analyses from public.users where id = 'b2222222-2222-2222-2222-222222222222') <> 3 then
    raise exception 'DOUBLE-CLAIM LEAK: claimer bonus changed on a repeat claim';
  end if;
end
$$;

-- 3. Self-referral: C claims its own code -> self_referral, no reward.
do $$
declare r text;
begin
  r := public.claim_referral('c3333333-3333-3333-3333-333333333333', 'CCCCCODE');
  if r <> 'self_referral' then raise exception 'expected self_referral, got %', r; end if;
  if (select bonus_analyses from public.users where id = 'c3333333-3333-3333-3333-333333333333') <> 0 then
    raise exception 'SELF-REFERRAL LEAK: self-claim granted a bonus';
  end if;
  if (select referred_by_user_id from public.users where id = 'c3333333-3333-3333-3333-333333333333') is not null then
    raise exception 'SELF-REFERRAL LEAK: self-claim set referred_by';
  end if;
end
$$;

-- 4. Invalid code: D claims a non-existent code -> invalid_code, no change.
do $$
declare r text;
begin
  r := public.claim_referral('d4444444-4444-4444-4444-444444444444', 'NOSUCH99');
  if r <> 'invalid_code' then raise exception 'expected invalid_code, got %', r; end if;
  if (select referred_by_user_id from public.users where id = 'd4444444-4444-4444-4444-444444444444') is not null then
    raise exception 'invalid claim should not set referred_by';
  end if;
end
$$;

-- 5. Lockdowns (catalog checks; no role-switch needed).
do $$
begin
  if has_function_privilege('authenticated', 'public.claim_referral(uuid, text)', 'execute') then
    raise exception 'LOCKDOWN: authenticated can execute claim_referral';
  end if;
  if not has_function_privilege('service_role', 'public.claim_referral(uuid, text)', 'execute') then
    raise exception 'service_role should execute claim_referral';
  end if;
  if has_table_privilege('authenticated', 'public.referrals', 'INSERT') then
    raise exception 'LOCKDOWN: authenticated can INSERT into referrals';
  end if;
  if not has_table_privilege('authenticated', 'public.referrals', 'SELECT') then
    raise exception 'authenticated should still SELECT its own referrals (RLS-gated)';
  end if;
  if has_column_privilege('authenticated', 'public.users', 'subscription_status', 'UPDATE') then
    raise exception 'LOCKDOWN: authenticated can UPDATE users.subscription_status';
  end if;
  if has_column_privilege('authenticated', 'public.users', 'bonus_analyses', 'UPDATE') then
    raise exception 'LOCKDOWN: authenticated can UPDATE users.bonus_analyses';
  end if;
  if not has_column_privilege('authenticated', 'public.users', 'one_signal_player_id', 'UPDATE') then
    raise exception 'authenticated should still UPDATE users.one_signal_player_id (OneSignal)';
  end if;
end
$$;

-- 6. The new-user trigger auto-assigns a referral_code.
do $$
begin
  insert into auth.users (id, email) values ('e5555555-5555-5555-5555-555555555555', 'trig@test');
  insert into public.users (id, email) values ('e5555555-5555-5555-5555-555555555555', 'trig@test');
  if (select referral_code from public.users where id = 'e5555555-5555-5555-5555-555555555555') is null then
    raise exception 'trigger did not assign a referral_code on insert';
  end if;
end
$$;

select 'REFERRAL FRAUD-CONTROL TESTS PASSED' as result;
