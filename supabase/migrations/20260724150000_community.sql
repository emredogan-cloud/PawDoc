-- =============================================================================
-- NEXT EVOLUTION PHASE 6 — PAW COMMUNITY v1 (2026-07-24)
--
-- Opt-in social layer: discover nearby pet owners, connect, chat 1:1, propose
-- walks. Trust and privacy are STRUCTURAL:
--   * opt-in only — a community_profiles row IS the opt-in; deleting it
--     dissolves the member's whole graph (connections/messages cascade);
--   * the ONLY location-shaped value stored is a 5-char geohash cell
--     (~±2.4 km) — never coordinates; discovery is cell-neighborhood matching;
--   * requests are gated by allow_requests; block goes silent server-side
--     (the messages INSERT policy requires an accepted connection);
--   * report + block ship in v1 (Play UGC policy) — reports are read by the
--     founder via service role (docs/runbooks/COMMUNITY_MODERATION.md).
-- This is NOT a family-sharing revert: different tables, different purpose,
-- no shared pet data — profiles are the only cross-user-readable rows.
-- =============================================================================

create table public.community_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 40),
  bio text check (bio is null or char_length(bio) <= 160),
  species_tags text[] not null default '{}',
  -- 5-char geohash cell (~±2.4 km). Nullable: a member may join without
  -- location (reachable via requests, invisible to nearby discovery).
  geohash text check (geohash is null or geohash ~ '^[0123456789bcdefghjkmnpqrstuvwxyz]{5}$'),
  is_discoverable boolean not null default true,
  allow_requests boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.community_profiles is
  'Paw Community membership (Next Evolution Phase 6). Row = opt-in. The only '
  'cross-user-readable table; geohash cell is the only location-shaped field.';

create index idx_community_profiles_discovery
  on public.community_profiles (geohash)
  where is_discoverable;

create table public.community_connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.community_profiles (user_id) on delete cascade,
  addressee_id uuid not null references public.community_profiles (user_id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create index idx_community_connections_addressee
  on public.community_connections (addressee_id, status);
create index idx_community_connections_requester
  on public.community_connections (requester_id, status);

create table public.community_messages (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null
    references public.community_connections (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index idx_community_messages_thread
  on public.community_messages (connection_id, created_at);

create table public.walk_proposals (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null
    references public.community_connections (id) on delete cascade,
  proposer_id uuid not null references auth.users (id) on delete cascade,
  place_name text not null check (char_length(place_name) between 1 and 80),
  note text check (note is null or char_length(note) <= 200),
  proposed_at timestamptz not null,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now()
);

create index idx_walk_proposals_thread
  on public.walk_proposals (connection_id, created_at);

create table public.community_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reported_user_id uuid not null references auth.users (id) on delete cascade,
  connection_id uuid references public.community_connections (id) on delete set null,
  reason text not null check (reason in ('spam', 'harassment', 'inappropriate', 'other')),
  details text check (details is null or char_length(details) <= 500),
  created_at timestamptz not null default now(),
  check (reporter_id <> reported_user_id)
);

comment on table public.community_reports is
  'UGC reports. Founder triages via service role; see '
  'docs/runbooks/COMMUNITY_MODERATION.md.';

-- Realtime for live chat. Guarded: the local RLS harness (vanilla postgres)
-- has no supabase_realtime publication.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    execute 'alter publication supabase_realtime add table public.community_messages';
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- RLS — per-operation policies, USING + WITH CHECK (CR #2 convention).
-- ---------------------------------------------------------------------------
alter table public.community_profiles enable row level security;

-- Discoverable profiles are readable by any signed-in member — that IS the
-- product (coarse fields only). Own row always readable.
create policy community_profiles_select on public.community_profiles
  for select using (
    (select auth.uid()) = user_id or is_discoverable
  );

create policy community_profiles_insert_own on public.community_profiles
  for insert with check ((select auth.uid()) = user_id);

create policy community_profiles_update_own on public.community_profiles
  for update using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy community_profiles_delete_own on public.community_profiles
  for delete using ((select auth.uid()) = user_id);

alter table public.community_connections enable row level security;

create policy community_connections_select_participant on public.community_connections
  for select using (
    (select auth.uid()) in (requester_id, addressee_id)
  );

-- Only as yourself, only pending, and only toward members who allow requests.
create policy community_connections_insert_request on public.community_connections
  for insert with check (
    (select auth.uid()) = requester_id
    and status = 'pending'
    and exists (
      select 1 from public.community_profiles p
      where p.user_id = addressee_id and p.allow_requests
    )
  );

-- Responding: the addressee may accept/decline/block; the requester may only
-- block (cancelling a pending request is a DELETE).
create policy community_connections_update_respond on public.community_connections
  for update using (
    (select auth.uid()) in (requester_id, addressee_id)
  )
  with check (
    (
      (select auth.uid()) = addressee_id
      and status in ('accepted', 'declined', 'blocked')
    )
    or (
      (select auth.uid()) = requester_id
      and status = 'blocked'
    )
  );

create policy community_connections_delete_participant on public.community_connections
  for delete using (
    (select auth.uid()) in (requester_id, addressee_id)
  );

alter table public.community_messages enable row level security;

create policy community_messages_select_participant on public.community_messages
  for select using (
    exists (
      select 1 from public.community_connections c
      where c.id = connection_id
        and (select auth.uid()) in (c.requester_id, c.addressee_id)
    )
  );

-- Send only as yourself, only inside your own ACCEPTED connection — a blocked
-- or pending thread is silent at the database, not just in the UI.
create policy community_messages_insert_participant on public.community_messages
  for insert with check (
    (select auth.uid()) = sender_id
    and exists (
      select 1 from public.community_connections c
      where c.id = connection_id
        and c.status = 'accepted'
        and (select auth.uid()) in (c.requester_id, c.addressee_id)
    )
  );

-- Messages are immutable; no UPDATE policy. Deleting own sent messages only.
create policy community_messages_delete_own on public.community_messages
  for delete using ((select auth.uid()) = sender_id);

alter table public.walk_proposals enable row level security;

create policy walk_proposals_select_participant on public.walk_proposals
  for select using (
    exists (
      select 1 from public.community_connections c
      where c.id = connection_id
        and (select auth.uid()) in (c.requester_id, c.addressee_id)
    )
  );

create policy walk_proposals_insert_participant on public.walk_proposals
  for insert with check (
    (select auth.uid()) = proposer_id
    and status = 'pending'
    and exists (
      select 1 from public.community_connections c
      where c.id = connection_id
        and c.status = 'accepted'
        and (select auth.uid()) in (c.requester_id, c.addressee_id)
    )
  );

-- Only the OTHER participant answers a proposal.
create policy walk_proposals_update_respond on public.walk_proposals
  for update using (
    (select auth.uid()) <> proposer_id
    and exists (
      select 1 from public.community_connections c
      where c.id = connection_id
        and (select auth.uid()) in (c.requester_id, c.addressee_id)
    )
  )
  with check (status in ('accepted', 'declined'));

create policy walk_proposals_delete_own on public.walk_proposals
  for delete using ((select auth.uid()) = proposer_id);

alter table public.community_reports enable row level security;

create policy community_reports_insert_own on public.community_reports
  for insert with check ((select auth.uid()) = reporter_id);

create policy community_reports_select_own on public.community_reports
  for select using ((select auth.uid()) = reporter_id);
