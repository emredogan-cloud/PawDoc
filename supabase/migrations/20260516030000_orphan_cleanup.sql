-- =============================================================================
-- Sprint B1 — Orphan pet-upload cleanup
-- =============================================================================
-- Closes H-8 / P1.7 from docs/reports/phase1-stabilization-plan.md.
--
-- The /analyze flow uploads images to `pet-uploads/<user_id>/...` BEFORE
-- it calls the AI service. When the AI call or persistence fails the
-- mobile shows a typed error and the user retries — but the object is
-- already in the bucket, and there's no `analyses` row referencing it.
-- Sprint A2's refund RPC closed the *quota* loop; this migration closes
-- the *storage* loop by giving the operator an idempotent way to purge
-- those orphans.
--
-- Discipline:
--   - Append-only mindset: the function never deletes objects newer
--     than `p_older_than` (default 7 days), so an in-flight analysis
--     is never wiped.
--   - Service-role only: REVOKE … FROM PUBLIC/anon/authenticated.
--   - Idempotent: re-running is a no-op once orphans are gone.
--   - Returns the deletion count for operator visibility / cron logs.
--
-- Production scheduling:
--   In prod, the operator enables pg_cron + schedules a daily run:
--     CREATE EXTENSION IF NOT EXISTS pg_cron;
--     SELECT cron.schedule(
--       'pawdoc-orphan-cleanup',
--       '0 4 * * *',
--       $$SELECT cleanup_orphan_pet_uploads();$$
--     );
--   The full procedure is in docs/operational-runbook.md §6.
--   Local dev intentionally does NOT install pg_cron — the function
--   can be invoked manually for testing.
-- =============================================================================

CREATE OR REPLACE FUNCTION cleanup_orphan_pet_uploads(
  p_older_than interval DEFAULT interval '7 days'
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
DECLARE
  v_count integer;
BEGIN
  -- Supabase ships a `storage.protect_delete` trigger that blocks
  -- direct DELETE on storage.objects. Service-role cleanup opts in
  -- via this GUC, scoped to the current transaction.
  PERFORM set_config('storage.allow_delete_query', 'true', true);

  WITH orphans AS (
    SELECT o.name
      FROM storage.objects o
     WHERE o.bucket_id = 'pet-uploads'
       AND o.created_at < (now() - p_older_than)
       AND NOT EXISTS (
         SELECT 1
           FROM public.analyses a
          WHERE a.input_storage_key = o.name
       )
  )
  DELETE FROM storage.objects o
   USING orphans
   WHERE o.bucket_id = 'pet-uploads'
     AND o.name = orphans.name;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION cleanup_orphan_pet_uploads(interval) IS
  'Delete pet-uploads objects older than the interval with no referencing analyses row. Service role only. Returns rows deleted.';

REVOKE ALL ON FUNCTION cleanup_orphan_pet_uploads(interval) FROM PUBLIC;
REVOKE ALL ON FUNCTION cleanup_orphan_pet_uploads(interval) FROM anon;
REVOKE ALL ON FUNCTION cleanup_orphan_pet_uploads(interval) FROM authenticated;
GRANT EXECUTE ON FUNCTION cleanup_orphan_pet_uploads(interval) TO service_role;
