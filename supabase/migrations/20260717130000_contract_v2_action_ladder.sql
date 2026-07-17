-- =============================================================================
-- CONTRACT v2 — ACTION LADDER (2026-07-17)
--
-- The AnalysisResult contract replaces the triage verdict
-- (EMERGENCY | MONITOR | NORMAL) with an action ladder that has NO terminal
-- "do nothing" state:
--   GET_HELP_NOW | CALL_TODAY | BOOK_VISIT | WATCH_AND_RECHECK
-- and replaces the diagnostic surface (`primary_concern` with condition names,
-- `differential`) with a plain-language `observation`.
--
-- Pre-launch: no production rows carry the old values on a launch DB; the
-- UPDATE below migrates any dev rows so the columns stay NOT-NULL-safe.
-- =============================================================================

-- --- 1. analyses: rename + remap ---------------------------------------------
alter table public.analyses rename column triage_level to action;
alter table public.analyses rename column primary_concern to observation;

update public.analyses set action = case action
  when 'EMERGENCY' then 'GET_HELP_NOW'
  when 'MONITOR'   then 'WATCH_AND_RECHECK'
  when 'NORMAL'    then 'WATCH_AND_RECHECK'
  else action
end;

-- Value guard: the ladder is closed — reject anything off-contract at the DB.
-- (The v1 CHECK survives the column rename under its old name; replace it.)
alter table public.analyses drop constraint if exists analyses_triage_level_chk;
alter table public.analyses drop constraint if exists analyses_action_check;
alter table public.analyses add constraint analyses_action_check
  check (action in ('GET_HELP_NOW', 'CALL_TODAY', 'BOOK_VISIT', 'WATCH_AND_RECHECK'));

-- --- 2. followup RPC: return the renamed column (semantics unchanged from
--        20260527050000 — RLS-scoped via SECURITY INVOKER, 72h, no-feedback,
--        limit 5) ------------------------------------------------------------
drop function if exists public.pending_followup_analyses();
create or replace function public.pending_followup_analyses()
returns table (id uuid, pet_id uuid, action text, created_at timestamptz)
language sql
stable
security invoker
set search_path = public
as $$
  select a.id, a.pet_id, a.action, a.created_at
  from public.analyses a
  where a.created_at < now() - interval '72 hours'
    and not exists (
      select 1 from public.analysis_feedback f where f.analysis_id = a.id
    )
  order by a.created_at desc
  limit 5;
$$;
grant execute on function public.pending_followup_analyses() to authenticated;

-- Index follows the renamed column (drop the old-name index; recreate).
drop index if exists idx_analyses_triage_level;
create index if not exists idx_analyses_action on public.analyses (action);

-- --- 3. accuracy views: reclassify on the ladder -----------------------------
-- FP proxy: GET_HELP_NOW but the vet said nothing / it resolved on its own.
-- FN proxy (the safety-critical class): a FLOOR read (WATCH_AND_RECHECK) where
-- a vet later confirmed a real problem. CALL_TODAY / BOOK_VISIT already
-- directed the owner to a professional, so they are not under-triage in the
-- v1 sense; they classify as directed_to_care when confirmed.
-- create-or-replace can't rename view columns; drop + recreate (summary first —
-- it depends on signals).
drop view if exists public.view_accuracy_summary;
drop view if exists public.view_accuracy_signals;
create view public.view_accuracy_signals as
select
  a.id                          as analysis_id,
  a.created_at                  as analyzed_at,
  a.action                      as ai_action,
  a.confidence_score            as ai_confidence,
  a.model_used                  as model_used,
  a.tier_used                   as tier_used,
  a.emergency_override_applied  as override_applied,
  f.outcome                     as user_outcome,
  f.rating                      as user_rating,
  f.created_at                  as feedback_at,
  case
    when a.action = 'GET_HELP_NOW'
         and f.outcome in ('vet_said_nothing', 'resolved_on_own')
      then 'false_positive_proxy'
    when a.action = 'WATCH_AND_RECHECK'
         and f.outcome = 'vet_confirmed'
      then 'false_negative_proxy'
    when a.action = 'GET_HELP_NOW' and f.outcome = 'vet_confirmed'
      then 'true_positive_proxy'
    when a.action in ('CALL_TODAY', 'BOOK_VISIT') and f.outcome = 'vet_confirmed'
      then 'directed_to_care'
    when a.action = 'WATCH_AND_RECHECK'
         and f.outcome in ('vet_said_nothing', 'resolved_on_own')
      then 'true_negative_proxy'
    else null
  end as signal
from public.analyses a
join public.analysis_feedback f on f.analysis_id = a.id
where f.outcome is not null;

comment on view public.view_accuracy_signals is
  'Admin-only accuracy proxy view (contract v2 action ladder). FN rows — a '
  'floor read the vet later confirmed — are the highest-value safety signals; '
  'feed them into ai-service/tests/golden_set.json.';

create view public.view_accuracy_summary as
select
  coalesce(signal, 'unclassified') as signal,
  count(*) as n
from public.view_accuracy_signals
group by 1
order by 1;

-- Re-assert lockdowns + invoker semantics (view redefinition resets nothing on
-- a real project, but be explicit — these views aggregate across users).
alter view public.view_accuracy_signals set (security_invoker = on);
alter view public.view_accuracy_summary set (security_invoker = on);
revoke all on public.view_accuracy_signals from public, anon, authenticated;
revoke all on public.view_accuracy_summary from public, anon, authenticated;
grant select on public.view_accuracy_signals to service_role;
grant select on public.view_accuracy_summary to service_role;
