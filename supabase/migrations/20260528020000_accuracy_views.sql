-- Phase 6.2 — Outcome Feedback Loop & Data Foundation.
--
-- This migration does three things:
--   1. Enforces the canonical outcome domain server-side: the Phase 4.1
--      `analysis_feedback.outcome` column was free text; we lock it to the five
--      values the roadmap names so junk values can never land.
--   2. Adds two PostgreSQL views for the AI-accuracy dashboards:
--        - `view_accuracy_signals`   per-row FP/FN/TP/TN proxy classification
--        - `view_accuracy_summary`   aggregate counts per signal class
--      Joining live analyses to user-reported outcomes is the closest proxy we
--      have to "did the AI get this right?" until we have vet-confirmed labels.
--   3. Locks down both views — REVOKE from `public` / `anon` / `authenticated`,
--      GRANT only to `service_role`. These views aggregate across users and are
--      strictly for admin/internal dashboards.
--
-- Why this is "the moat seed": the false-negative proxy (AI said NORMAL,
-- outcome was `vet_confirmed`) is the highest-value signal we can collect —
-- those rows go directly into the Phase 6.1 golden set so the safety regression
-- harness grows from real incidents, not synthetic ones.

-- 1. Outcome categorization enforcement -----------------------------------
-- Only NULL (thumbs-up/down feedback path that doesn't carry an outcome) or
-- one of the five canonical values is allowed. NOT VALID is omitted: the column
-- has been populated by the client app since Phase 4.1 with exactly these
-- values, so the existing data already satisfies the constraint.
alter table public.analysis_feedback
  add constraint analysis_feedback_outcome_check
  check (
    outcome is null
    or outcome in (
      'resolved_on_own',
      'vet_confirmed',
      'vet_said_nothing',
      'still_monitoring',
      'other'
    )
  );

-- 2. Accuracy signal view (per row) ---------------------------------------
-- Joins each analysis to the user's eventual outcome, when one exists. The
-- `signal` column is the headline classification the founder reads off the
-- dashboard; it intentionally ignores rows where the user hasn't picked an
-- outcome (rating-only / comment-only feedback) so the proxy stays clean.
--
-- Definitions (per the roadmap):
--   * false_positive_proxy: AI said EMERGENCY, but the user-reported outcome was
--     `vet_said_nothing` (vet checked, said it was nothing) or `resolved_on_own`
--     (no vet visit needed). The model over-triaged.
--   * false_negative_proxy: AI said NORMAL, but the user-reported outcome was
--     `vet_confirmed` (a vet confirmed a real problem). The model under-triaged
--     — the safety-critical class. These rows MUST be reviewed and the
--     incident text added to ai-service/tests/golden_set.json.
--   * true_positive_proxy:  AI said EMERGENCY and the vet confirmed it.
--   * true_negative_proxy:  AI said NORMAL and the issue resolved on its own /
--     the vet said it was nothing.
--   * (NULL signal) MONITOR triage rows, or outcomes we can't classify cleanly
--     (e.g. `still_monitoring`, `other`) — kept in the view for completeness
--     but excluded from the FP/FN/TP/TN counts.

create or replace view public.view_accuracy_signals as
select
  a.id                          as analysis_id,
  a.created_at                  as analyzed_at,
  a.triage_level                as ai_triage,
  a.confidence_score            as ai_confidence,
  a.model_used                  as model_used,
  a.tier_used                   as tier_used,
  a.emergency_override_applied  as override_applied,
  f.outcome                     as user_outcome,
  f.rating                      as user_rating,
  f.created_at                  as feedback_at,
  case
    when a.triage_level = 'EMERGENCY'
         and f.outcome in ('vet_said_nothing', 'resolved_on_own')
      then 'false_positive_proxy'
    when a.triage_level = 'NORMAL'
         and f.outcome = 'vet_confirmed'
      then 'false_negative_proxy'
    when a.triage_level = 'EMERGENCY' and f.outcome = 'vet_confirmed'
      then 'true_positive_proxy'
    when a.triage_level = 'NORMAL'
         and f.outcome in ('vet_said_nothing', 'resolved_on_own')
      then 'true_negative_proxy'
    else null
  end as signal
from public.analyses a
join public.analysis_feedback f on f.analysis_id = a.id
where f.outcome is not null;

comment on view public.view_accuracy_signals is
  'Phase 6.2 admin-only accuracy proxy view. Joins analyses to user-reported '
  'outcomes; the `signal` column flags FP/FN/TP/TN. FN rows are the highest-'
  'value safety signals — feed them into ai-service/tests/golden_set.json.';

-- 3. Aggregate summary view (rates per signal class) ---------------------
create or replace view public.view_accuracy_summary as
select
  coalesce(signal, 'unclassified') as signal,
  count(*) as n
from public.view_accuracy_signals
group by 1
order by 1;

comment on view public.view_accuracy_summary is
  'Phase 6.2 admin-only — per-signal counts of view_accuracy_signals.';

-- 4. Lockdowns ------------------------------------------------------------
-- These views aggregate across users; they MUST NOT be reachable via the anon
-- or authenticated PostgREST grants. Only service_role (server-side admin
-- tooling) keeps SELECT access. The founder reads them via the Supabase Studio
-- SQL editor, which runs as postgres.
revoke all on public.view_accuracy_signals from public, anon, authenticated;
revoke all on public.view_accuracy_summary from public, anon, authenticated;
grant select on public.view_accuracy_signals to service_role;
grant select on public.view_accuracy_summary to service_role;
