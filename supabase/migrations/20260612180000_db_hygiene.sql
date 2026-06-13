-- GAP-E14: DB hygiene — CHECK constraints on code-bounded enum columns, hot-path
-- indexes, and security_invoker on the accuracy views.
--
-- Value sets VERIFIED against the live code (reality > reports):
--   * triage_level  -> EMERGENCY | MONITOR | NORMAL  (ai-service models.py +
--     mobile analysis_result.dart wireValue). NOT 'LIKELY_NORMAL'.
--   * input_type    -> photo | video | text  (analyze/index.ts validation).
--   * species       -> kSpecies (mobile/lib/src/pets/pet.dart).
--
-- DEFERRED (real breakage risk — not taken blind):
--   * subscription_status CHECK — the RevenueCat webhook writes
--     entitlementStatusFromEvent(event); the full value set must be audited
--     before a CHECK, or a webhook write could fail and strand a paid user.
--   * revoke execute on count_shared_group_memberships from authenticated — it is
--     granted to authenticated AND called by accept-family-invite; revoking could
--     break invite acceptance. Verify the calling client first.
--   * PDF decrement guard — app/service-side, not a constraint.

-- 1. Enum integrity (CHECK constraints).
alter table public.analyses
  add constraint analyses_triage_level_chk
  check (triage_level in ('EMERGENCY', 'MONITOR', 'NORMAL'));

alter table public.analyses
  add constraint analyses_input_type_chk
  check (input_type in ('photo', 'video', 'text'));

alter table public.pets
  add constraint pets_species_chk
  check (species in ('dog', 'cat', 'rabbit', 'guinea_pig', 'bird', 'reptile', 'other'));

-- 2. Indexes on hot RLS predicates / FK lookups (idempotent).
create index if not exists idx_health_events_pet_id on public.health_events (pet_id);
create index if not exists idx_analysis_feedback_analysis_id on public.analysis_feedback (analysis_id);
create index if not exists idx_reminders_user_id on public.reminders (user_id);
create index if not exists idx_reminders_pet_id on public.reminders (pet_id);
create index if not exists idx_referrals_referrer_user_id on public.referrals (referrer_user_id);
create index if not exists idx_pets_user_id on public.pets (user_id);

-- 3. security_invoker on the accuracy views — evaluated with the querying user's
--    own RLS instead of the view owner's, closing the L-4 info-exposure path.
alter view public.view_accuracy_signals set (security_invoker = on);
alter view public.view_accuracy_summary set (security_invoker = on);
