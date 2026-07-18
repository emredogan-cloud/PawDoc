-- =============================================================================
-- EVOLUTION SUBTRACTION (2026-07-17) — DB reversal for the pre-launch feature
-- subtraction (PAWDOC_PRODUCT_EVOLUTION_MASTERPLAN Phase 1).
--
-- Removes: referral, family sharing, AI health journals, b2b_lite/sitter,
-- PDF add-on credits, OneSignal push, re-engagement, and the semantic cache.
-- RLS on pets/analyses/health_events/reminders reverts to OWNER-ONLY with
-- explicit per-operation policies (USING + WITH CHECK — the project rule).
--
-- Pre-launch: there are no production users; drops are irreversible by design.
-- Also fixes RLS-01 at the root — the referral FKs that made account deletion
-- 500 no longer exist at all.
-- =============================================================================

-- --- 0. Unschedule the feature crons (managed pg_cron exists on real projects
--        only; guard so the local harness (no cron schema) applies cleanly).
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'process-reminders-hourly') then
      perform cron.unschedule('process-reminders-hourly');
    end if;
    if exists (select 1 from cron.job where jobname = 'generate-journals-weekly') then
      perform cron.unschedule('generate-journals-weekly');
    end if;
  end if;
end
$$;

-- --- 1. Family sharing — triggers, helper functions, policies, tables --------
drop trigger if exists pets_default_family_group on public.pets;
drop trigger if exists users_create_solo_family on public.users;
drop trigger if exists on_user_delete_reassign_family on public.users;
drop function if exists public.default_pet_family_group();
drop function if exists public.create_solo_family_for_new_user();
drop function if exists public.handle_owner_deletion_family_reassign();
drop function if exists public.count_shared_group_memberships(uuid);

-- Family-scoped policies off the four shared tables.
drop policy if exists pets_select_family        on public.pets;
drop policy if exists pets_insert_own_in_family on public.pets;
drop policy if exists pets_update_owner         on public.pets;
drop policy if exists pets_delete_owner         on public.pets;
drop policy if exists analyses_select_family    on public.analyses;
drop policy if exists analyses_insert_member    on public.analyses;
drop policy if exists analyses_update_owner     on public.analyses;
drop policy if exists analyses_delete_owner     on public.analyses;
drop policy if exists health_events_select_family on public.health_events;
drop policy if exists health_events_insert_member on public.health_events;
drop policy if exists health_events_update_member on public.health_events;
drop policy if exists health_events_delete_member on public.health_events;
drop policy if exists reminders_select_family   on public.reminders;
drop policy if exists reminders_insert_member   on public.reminders;
drop policy if exists reminders_update_owner    on public.reminders;
drop policy if exists reminders_delete_owner    on public.reminders;

-- Drop the family tables BEFORE the membership helpers — the tables' own
-- policies depend on is_family_member; dropping a table drops its policies.
alter table public.pets drop column if exists family_group_id;
drop table if exists public.family_invites;
drop table if exists public.family_members;
drop table if exists public.family_groups;
drop function if exists public.is_family_member(uuid);
drop function if exists public.is_family_pet(uuid);

-- Owner-only, explicit per-operation policies (USING + WITH CHECK).
create policy pets_select_own on public.pets
  for select using ((select auth.uid()) = user_id);
create policy pets_insert_own on public.pets
  for insert with check ((select auth.uid()) = user_id);
create policy pets_update_own on public.pets
  for update using ((select auth.uid()) = user_id)
             with check ((select auth.uid()) = user_id);
create policy pets_delete_own on public.pets
  for delete using ((select auth.uid()) = user_id);

create policy analyses_select_own on public.analyses
  for select using ((select auth.uid()) = user_id);
create policy analyses_insert_own on public.analyses
  for insert with check ((select auth.uid()) = user_id);
create policy analyses_update_own on public.analyses
  for update using ((select auth.uid()) = user_id)
             with check ((select auth.uid()) = user_id);
create policy analyses_delete_own on public.analyses
  for delete using ((select auth.uid()) = user_id);

-- health_events has no user_id column — ownership derives from the parent pet.
create policy health_events_select_own on public.health_events
  for select using (exists (
    select 1 from public.pets p
    where p.id = health_events.pet_id and p.user_id = (select auth.uid())));
create policy health_events_insert_own on public.health_events
  for insert with check (exists (
    select 1 from public.pets p
    where p.id = health_events.pet_id and p.user_id = (select auth.uid())));
create policy health_events_update_own on public.health_events
  for update using (exists (
    select 1 from public.pets p
    where p.id = health_events.pet_id and p.user_id = (select auth.uid())))
  with check (exists (
    select 1 from public.pets p
    where p.id = health_events.pet_id and p.user_id = (select auth.uid())));
create policy health_events_delete_own on public.health_events
  for delete using (exists (
    select 1 from public.pets p
    where p.id = health_events.pet_id and p.user_id = (select auth.uid())));

create policy reminders_select_own on public.reminders
  for select using ((select auth.uid()) = user_id);
create policy reminders_insert_own on public.reminders
  for insert with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.pets p
      where p.id = reminders.pet_id and p.user_id = (select auth.uid())));
create policy reminders_update_own on public.reminders
  for update using ((select auth.uid()) = user_id)
             with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.pets p
      where p.id = reminders.pet_id and p.user_id = (select auth.uid())));
create policy reminders_delete_own on public.reminders
  for delete using ((select auth.uid()) = user_id);

-- --- 2. Referral (root fix for RLS-01: the un-cascaded FKs cease to exist) ---
drop trigger if exists users_set_referral_code on public.users;
drop function if exists public.set_referral_code();
drop trigger if exists trg_cap_bonus_analyses on public.users;
drop function if exists public.cap_bonus_analyses();
drop function if exists public.claim_referral(uuid, text);
drop table if exists public.referrals;
alter table public.users drop column if exists referred_by_user_id;
alter table public.users drop column if exists bonus_analyses;
alter table public.users drop column if exists referral_code;

-- --- 3. AI health journals ---------------------------------------------------
drop function if exists public.pets_pending_journal(date);
drop table if exists public.health_journals;
alter table public.pets drop column if exists is_journal_enabled;

-- --- 4. B2B-Lite / sitter mode ----------------------------------------------
alter table public.pets drop column if exists client_name;

-- --- 5. PDF add-on credits (PDF reports are premium-included) ----------------
alter table public.users drop column if exists pdf_reports_remaining;

-- --- 6. OneSignal push + re-engagement ---------------------------------------
drop function if exists public.users_to_reengage(int, int);
drop function if exists public.due_reminders();
alter table public.users drop column if exists one_signal_player_id;
alter table public.users drop column if exists last_reengagement_sent_at;

-- --- 7. Semantic cache -------------------------------------------------------
drop function if exists public.match_analyses(extensions.vector, uuid, text, double precision, integer);
alter table public.analyses drop column if exists embedding;
