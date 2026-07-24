-- =============================================================================
-- NEXT EVOLUTION PHASE 4 — PAWDOC AI ASSISTANT (2026-07-24)
--
-- Conversation store for the guardrailed assistant surface. The Edge Function
-- /assistant-chat is the only writer of assistant-role rows (service role,
-- after the model stream completes); user-role rows are inserted through the
-- caller's OWN JWT so RLS WITH CHECK stays load-bearing. The client reads
-- history directly via RLS. The emergency path never touches these tables —
-- emergency messages are intercepted BEFORE persistence and never counted.
-- =============================================================================

create table public.assistant_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  -- Conversations may be pet-flavored; losing the pet keeps the conversation.
  pet_id uuid references public.pets (id) on delete set null,
  title text not null check (char_length(title) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.assistant_conversations is
  'AI assistant conversations (Next Evolution Phase 4). Owner-only via RLS.';

create index idx_assistant_conversations_recent
  on public.assistant_conversations (user_id, updated_at desc);

create table public.assistant_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.assistant_conversations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (char_length(content) between 1 and 20000),
  -- Optional chat/ scoped R2 key for an attached photo (own-namespace only,
  -- enforced by the Edge Function's key gate).
  image_storage_key text check (
    image_storage_key is null or char_length(image_storage_key) <= 200
  ),
  created_at timestamptz not null default now()
);

comment on table public.assistant_messages is
  'AI assistant messages. user rows are written under the caller''s JWT; '
  'assistant rows are written by the Edge Function after the stream completes. '
  'The free daily allowance counts user rows per UTC day.';

create index idx_assistant_messages_conversation
  on public.assistant_messages (conversation_id, created_at);
-- Backs the daily-allowance count (user_id + role + created_at).
create index idx_assistant_messages_daily_quota
  on public.assistant_messages (user_id, role, created_at);

-- ---------------------------------------------------------------------------
-- RLS — per-operation policies, USING + WITH CHECK (CR #2 convention).
-- ---------------------------------------------------------------------------
alter table public.assistant_conversations enable row level security;

create policy assistant_conversations_select_own on public.assistant_conversations
  for select using ((select auth.uid()) = user_id);

create policy assistant_conversations_insert_own on public.assistant_conversations
  for insert with check (
    (select auth.uid()) = user_id
    and (
      pet_id is null
      or exists (
        select 1 from public.pets p
        where p.id = pet_id and p.user_id = (select auth.uid())
      )
    )
  );

-- Rename only (title); ownership and pet pinning re-checked.
create policy assistant_conversations_update_own on public.assistant_conversations
  for update using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (
      pet_id is null
      or exists (
        select 1 from public.pets p
        where p.id = pet_id and p.user_id = (select auth.uid())
      )
    )
  );

create policy assistant_conversations_delete_own on public.assistant_conversations
  for delete using ((select auth.uid()) = user_id);

alter table public.assistant_messages enable row level security;

create policy assistant_messages_select_own on public.assistant_messages
  for select using ((select auth.uid()) = user_id);

-- The caller may insert only their OWN user-role turns into their OWN
-- conversation. assistant-role rows come from the service role (bypasses RLS)
-- so a client can never forge a model reply.
create policy assistant_messages_insert_own on public.assistant_messages
  for insert with check (
    (select auth.uid()) = user_id
    and role = 'user'
    and exists (
      select 1 from public.assistant_conversations c
      where c.id = conversation_id and c.user_id = (select auth.uid())
    )
  );

-- Messages are immutable for clients (no UPDATE policy). Deletion happens via
-- the conversation cascade; direct row deletes stay owner-only.
create policy assistant_messages_delete_own on public.assistant_messages
  for delete using ((select auth.uid()) = user_id);
