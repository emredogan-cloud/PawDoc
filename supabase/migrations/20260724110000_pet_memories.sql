-- =============================================================================
-- NEXT EVOLUTION PHASE 2 — PET MEMORIES (2026-07-24)
--
-- A personal pet photo journal: each row is one memory (photo + title + note +
-- date). Photos live in R2 under the caller's own `memories/<uid>/` namespace
-- (presigned PUT via generate-upload-url scope=memories; presigned GET via
-- sign-media-url; object delete via delete-media; account-deletion purge covers
-- the prefix). This is the "paid = memory" product pillar becoming a first-class
-- surface — no AI, no safety logic, human content only.
-- =============================================================================

create table public.pet_memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  pet_id uuid not null references public.pets (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  note text check (note is null or char_length(note) <= 600),
  -- R2 object key `memories/<uid>/<uuid>.<ext>` — shape enforced app-side by
  -- _shared/upload_key.mjs; unique so two rows never share one object (a
  -- row delete may safely delete its object).
  storage_key text not null unique check (char_length(storage_key) <= 200),
  -- The day the memory happened (user-editable), distinct from created_at.
  taken_on date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.pet_memories is
  'Pet photo journal (Next Evolution Phase 2). Owner-only via RLS; photo bytes '
  'in R2 under memories/<uid>/, addressed by storage_key.';

-- Timeline reads: newest memory day first within a pet.
create index idx_pet_memories_owner_timeline
  on public.pet_memories (user_id, pet_id, taken_on desc, created_at desc);

-- ---------------------------------------------------------------------------
-- RLS — per-operation policies, USING + WITH CHECK (CR #2 convention).
-- INSERT/UPDATE additionally pin pet_id to a pet the caller owns, so a memory
-- can never be attached to another user's pet.
-- ---------------------------------------------------------------------------
alter table public.pet_memories enable row level security;

create policy pet_memories_select_own on public.pet_memories
  for select using ((select auth.uid()) = user_id);

create policy pet_memories_insert_own on public.pet_memories
  for insert with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.pets p
      where p.id = pet_id and p.user_id = (select auth.uid())
    )
  );

create policy pet_memories_update_own on public.pet_memories
  for update using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.pets p
      where p.id = pet_id and p.user_id = (select auth.uid())
    )
  );

create policy pet_memories_delete_own on public.pet_memories
  for delete using ((select auth.uid()) = user_id);
