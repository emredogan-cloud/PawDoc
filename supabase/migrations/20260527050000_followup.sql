-- Phase 4.1 — 72h "was this helpful?" follow-up eligibility.
--
-- analysis_feedback RLS ALREADY EXISTS (CR #2, migration 20260527010001): a user
-- may read/write feedback only for their OWN analyses — ownership is derived
-- from the parent analysis (the table has no user_id column), enforced by both
-- USING and WITH CHECK. This migration does NOT change that; it only adds the
-- eligibility query the client needs.
--
-- pending_followup_analyses() is SECURITY INVOKER, so when the authenticated app
-- calls it, RLS on analyses + analysis_feedback is enforced with the caller's
-- auth.uid(): it sees only the caller's analyses, and the NOT EXISTS naturally
-- checks the caller's own feedback. Eligible = an analysis older than 72h that
-- has no feedback row yet (so the 72h prompt fires once per analysis).
create or replace function public.pending_followup_analyses()
returns table (id uuid, pet_id uuid, triage_level text, created_at timestamptz)
language sql
stable
security invoker
set search_path = public
as $$
  select a.id, a.pet_id, a.triage_level, a.created_at
  from public.analyses a
  where a.created_at < now() - interval '72 hours'
    and not exists (
      select 1 from public.analysis_feedback f where f.analysis_id = a.id
    )
  order by a.created_at desc
  limit 5;
$$;

grant execute on function public.pending_followup_analyses() to authenticated;
