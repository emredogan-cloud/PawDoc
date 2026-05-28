-- Phase 6.3.1 — Family Sharing invite + accept.
--
-- Adds `family_invites` to back the invite flow on top of the per-family-group
-- RLS from Phase 6.3. Pending invites carry a high-entropy URL-safe token,
-- expire in 48 hours by default, and are write-only via the service role
-- (the /invite-family-member and /accept-family-invite Edge Functions).
--
-- A SECURITY DEFINER helper (`count_shared_group_memberships`) lets the
-- accept-invite path block users who are already in any family group beyond
-- their solo one — the safer MVP behavior, as the task brief calls out.

create table public.family_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.family_groups (id) on delete cascade,
  invited_by_user_id uuid not null references public.users (id) on delete cascade,
  invited_email text,                                   -- lowercased; optional for share-link flow
  token text not null unique,                           -- high-entropy URL-safe random
  expires_at timestamptz not null default now() + interval '48 hours',
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'expired', 'revoked')),
  accepted_by_user_id uuid references public.users (id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz default now()
);

create index family_invites_token_idx        on public.family_invites (token);
create index family_invites_group_status_idx on public.family_invites (group_id, status);

comment on table public.family_invites is
  'Phase 6.3.1 — pending invites for the per-family-group RLS. Tokens are '
  '48h-expiring + single-use; writes are service-role-only via the Edge '
  'Functions /invite-family-member and /accept-family-invite.';

-- RLS — SELECT only by the inviter. INSERT/UPDATE/DELETE are revoked from
-- both anon and authenticated; the Edge Functions use the service-role key.
alter table public.family_invites enable row level security;

create policy family_invites_select_by_inviter on public.family_invites
  for select using ((select auth.uid()) = invited_by_user_id);

revoke insert, update, delete on public.family_invites from anon, authenticated;
grant select on public.family_invites to service_role;
grant insert, update, delete on public.family_invites to service_role;

-- Helper used by the accept-invite Edge Function — counts how many groups the
-- caller belongs to where the group has more than one member (i.e. "shared
-- families", as opposed to the solo group everyone has). SECURITY DEFINER so
-- it sees all family_members rows for the counted groups (RLS would otherwise
-- hide groups the user isn't a direct member of from the COUNT).
create or replace function public.count_shared_group_memberships(check_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(count(*), 0)::int
  from public.family_members fm
  where fm.user_id = check_user_id
    and (
      select count(*) from public.family_members fm2 where fm2.group_id = fm.group_id
    ) > 1;
$$;

revoke all on function public.count_shared_group_memberships(uuid) from public;
grant execute on function public.count_shared_group_memberships(uuid) to authenticated, service_role;
