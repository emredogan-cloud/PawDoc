-- GAP-E12: re-assert the family/tenant boundary on UPDATE.
--
-- The family-aware UPDATE policies (pets / analyses / reminders) only checked
-- `auth.uid() = user_id` in WITH CHECK. Their matching INSERT policies ALSO
-- require the row to belong to a family group / pet the writer is a member of
-- (is_family_member / is_family_pet) — but UPDATE did not. So an owner could
-- UPDATE their own row and re-point it into a STRANGER'S group/pet:
--   * pets.family_group_id      -> a group the writer isn't a member of
--   * analyses.pet_id           -> a pet outside the writer's family
--   * reminders.pet_id          -> a pet outside the writer's family
-- Because the SELECT policies are membership-based, that injects the writer's
-- row into the stranger's feed (cross-tenant injection / nuisance vector).
--
-- Fix: each UPDATE WITH CHECK now re-asserts membership on the NEW row, exactly
-- like its INSERT policy. USING is unchanged (still owner-only to initiate the
-- update), so this only tightens — it never widens — access.

drop policy if exists pets_update_owner on public.pets;
create policy pets_update_owner on public.pets
  for update using ((select auth.uid()) = user_id)
                with check (
                  (select auth.uid()) = user_id
                  and public.is_family_member(family_group_id)
                );

drop policy if exists analyses_update_owner on public.analyses;
create policy analyses_update_owner on public.analyses
  for update using ((select auth.uid()) = user_id)
                with check (
                  (select auth.uid()) = user_id
                  and public.is_family_pet(pet_id)
                );

drop policy if exists reminders_update_owner on public.reminders;
create policy reminders_update_owner on public.reminders
  for update using ((select auth.uid()) = user_id)
                with check (
                  (select auth.uid()) = user_id
                  and public.is_family_pet(pet_id)
                );
