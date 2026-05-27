-- Phase 3.3 — Referral claim, rewards & fraud controls (CR #14 / #25).
--
-- Adds the columns the claim flow needs, a transactional RPC that grants the
-- reward atomically, and the security lockdowns the strict-rule requires:
--   * referrals is NOT client-writable (writes only via the RPC / service role);
--   * the reward columns on users are NOT client-writable either.
--
-- Fraud invariants enforced in the DB:
--   * one claim per lifetime  -> users.referred_by_user_id set once (+ a UNIQUE
--                                referrals.referred_user_id as defense-in-depth);
--   * no self-referral        -> RPC rejects referrer = claimer;
--   * race / double-click safe -> the RPC locks the claimer row FOR UPDATE so
--                                concurrent calls serialize and the 2nd sees the
--                                claim already set.

-- 1. New columns --------------------------------------------------------------
alter table public.users add column referral_code text;        -- this user's own code
alter table public.users add column referred_by_user_id uuid references public.users (id); -- set once on claim
alter table public.users add column bonus_analyses int not null default 0;                 -- reward pool (one-time credits)

-- The referee side of a referral, UNIQUE => a user can be referred at most once.
alter table public.referrals add column referred_user_id uuid references public.users (id);
alter table public.referrals add constraint referrals_referred_user_id_key unique (referred_user_id);

-- 2. referral_code: matches the existing 1.4 client scheme (first 8 hex of the
--    UID, uppercased). Backfill, then UNIQUE, then a trigger for new rows that
--    extends the length on the (rare) collision so signup never fails.
update public.users set referral_code = upper(left(replace(id::text, '-', ''), 8)) where referral_code is null;
alter table public.users add constraint users_referral_code_key unique (referral_code);

create or replace function public.set_referral_code() returns trigger
language plpgsql
set search_path = public
as $$
declare
  base text := upper(replace(new.id::text, '-', ''));
  candidate text;
  n int := 8;
begin
  if new.referral_code is not null then
    return new;
  end if;
  loop
    candidate := left(base, n);
    exit when not exists (select 1 from public.users where referral_code = candidate);
    n := n + 2;
    if n >= length(base) then
      candidate := base;  -- full UID hex is unique (it is the PK) -> always terminates
      exit;
    end if;
  end loop;
  new.referral_code := candidate;
  return new;
end;
$$;

create trigger users_set_referral_code
  before insert on public.users
  for each row execute function public.set_referral_code();

-- 3. Atomic claim RPC ---------------------------------------------------------
-- Returns one of: 'success' | 'invalid_code' | 'self_referral' | 'already_claimed'.
-- SECURITY DEFINER so it can update both users rows + write referrals despite
-- the client-side lockdowns below; callable ONLY by the service role.
create or replace function public.claim_referral(claimer_id uuid, code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referrer uuid;
  v_existing uuid;
  v_email text;
  v_code text := upper(trim(code));
begin
  -- Lock the claimer's row: concurrent claims (rapid taps) serialize here, so
  -- the second caller observes referred_by_user_id already set.
  select referred_by_user_id, email into v_existing, v_email
    from public.users where id = claimer_id for update;
  if not found then
    return 'invalid_code';
  end if;
  if v_existing is not null then
    return 'already_claimed';
  end if;

  select id into v_referrer from public.users where referral_code = v_code;
  if v_referrer is null then
    return 'invalid_code';
  end if;
  if v_referrer = claimer_id then
    return 'self_referral';
  end if;

  -- Single transaction: mark claimed + reward both sides.
  update public.users
    set referred_by_user_id = v_referrer, bonus_analyses = bonus_analyses + 3
    where id = claimer_id;
  update public.users
    set bonus_analyses = bonus_analyses + 3
    where id = v_referrer;
  insert into public.referrals (referrer_user_id, referred_user_id, referred_email, converted, converted_at)
    values (v_referrer, claimer_id, v_email, true, now());

  return 'success';
exception
  when unique_violation then
    -- The referred_user_id UNIQUE caught a double-claim that slipped the lock.
    return 'already_claimed';
end;
$$;

-- 4. Lockdowns (strict rule: claim + rewards only via the RPC/service role) ---
-- The RPC: server-only, so a user cannot pass an arbitrary claimer_id via PostgREST.
revoke all on function public.claim_referral(uuid, text) from public, anon, authenticated;
grant execute on function public.claim_referral(uuid, text) to service_role;

-- referrals: clients may read their own (existing RLS policy) but NEVER write.
revoke insert, update, delete on public.referrals from anon, authenticated;

-- users: clients may no longer UPDATE arbitrary columns of their own row (which
-- previously allowed self-granting premium / zeroing the free counter / writing
-- bonus_analyses). Re-grant ONLY the one column the client legitimately writes
-- (OneSignal player id). All sensitive columns are now server-only. RLS still
-- gates the row; this gates the columns.
revoke update on public.users from anon, authenticated;
grant update (one_signal_player_id) on public.users to authenticated;
