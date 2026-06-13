-- GAP-E16: cap the lifetime referral bonus at 30 credits (~10 referrals). With
-- email auto-confirm, referrals are near-free to farm (ties to E3). A BEFORE
-- trigger clamps users.bonus_analyses to <= 30 on any write, so the existing
-- claim_referral (+3 to each side) can never push a user past the cap — without
-- touching the SECURITY DEFINER claim function. Decrements (spending a bonus
-- credit) go down, so the clamp never affects them.
create or replace function public.cap_bonus_analyses()
returns trigger
language plpgsql
as $$
begin
  if new.bonus_analyses > 30 then
    new.bonus_analyses := 30;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_cap_bonus_analyses on public.users;
create trigger trg_cap_bonus_analyses
  before insert or update on public.users
  for each row execute function public.cap_bonus_analyses();

comment on function public.cap_bonus_analyses() is
  'GAP-E16: clamps referral bonus_analyses to a lifetime max of 30 (anti-farming).';
