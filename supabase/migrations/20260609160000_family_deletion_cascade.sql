-- Phase B — Family-Deletion Cascade Compliance Fix (RF-4 / H1).
--
-- PROBLEM: a shared-group OWNER could not delete their account.
--   family_groups.owner_user_id  -> public.users(id)     ON DELETE CASCADE
--   pets.family_group_id         -> family_groups(id)    ON DELETE RESTRICT  (NOT NULL)
-- Deleting an owner cascades away their owned family_groups, but any CO-MEMBER's
-- pet still pointing at that group trips the RESTRICT -> the whole deleteUser
-- 500s (GDPR / Apple 5.1.1(v) violation); co-members are also silently orphaned.
-- (Solo deletion already works: the owner's own pet cascades via pets.user_id in
-- the same statement.)
--
-- FIX (dissolve + reassign, founder-approved): a BEFORE DELETE trigger on
-- public.users moves every CO-MEMBER pet out of the departing owner's groups and
-- back to that co-member's OWN solo group BEFORE the cascade runs. Then the
-- owner's groups hold only the owner's own pets (which cascade via pets.user_id),
-- so the RESTRICT can't fire and no other user's pet is ever lost. Co-members'
-- membership rows in the dissolved group are removed by the existing
-- family_members.group_id ON DELETE CASCADE.
--
-- Enforced at the DB layer so it is correct regardless of the deletion path
-- (delete-account Edge Function, admin API, or a raw cascade). delete-account
-- stays a thin deleteUser call. SECURITY DEFINER because it reassigns pets owned
-- by other users (bypasses RLS); it only ever fires on a public.users DELETE,
-- which is a service-role/superuser-only operation.
--
-- Invariant relied upon: every user has a solo family_group (created by
-- users_create_solo_family on public.users INSERT). Phase C further hardens that
-- provisioning. If a co-member somehow had no owned group the reassignment target
-- would be NULL; that cannot occur under the invariant, and Phase C closes the
-- single point of failure that could otherwise break it.

create or replace function public.handle_owner_deletion_family_reassign()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.pets p
     set family_group_id = (
       -- the co-member's own solo group (their oldest owned group)
       select fg.id
       from public.family_groups fg
       where fg.owner_user_id = p.user_id
       order by fg.created_at asc
       limit 1
     )
   where p.user_id <> old.id                       -- only OTHER users' pets
     and p.family_group_id in (                    -- ...currently in a group the departing user owns
       select id from public.family_groups where owner_user_id = old.id
     );
  return old;
end;
$$;

drop trigger if exists on_user_delete_reassign_family on public.users;
create trigger on_user_delete_reassign_family
  before delete on public.users
  for each row execute function public.handle_owner_deletion_family_reassign();
