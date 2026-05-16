-- =============================================================================
-- Sprint A2 — Free-tier quota refund infrastructure
-- =============================================================================
-- Closes P0.3 from docs/reports/phase1-stabilization-plan.md.
--
-- The analyze edge function consumes a free-tier slot BEFORE the AI call
-- (so users can't game the counter by submitting then disconnecting). If
-- the AI call or the analysis persistence fails after that, the slot is
-- effectively wasted — the user paid quota for nothing. This migration
-- adds the audit table + RPC that gives the edge function's catch arms
-- a safe, idempotent way to refund the quota.
--
-- Discipline:
--   - Refunds are append-only.
--   - Idempotency is enforced by a UNIQUE constraint on request_id; the
--     same request can be refunded at most once.
--   - The function locks the user row (FOR UPDATE) so concurrent refund +
--     consume attempts don't race.
--   - The function is service-role only; users cannot call it.
-- =============================================================================

CREATE TABLE analysis_refunds (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  request_id   text NOT NULL UNIQUE,
  reason       text NOT NULL,
  refunded_at  timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT analysis_refunds_reason_check
    CHECK (reason IN ('ai_failure', 'persist_failure', 'timeout', 'admin'))
);

CREATE INDEX idx_analysis_refunds_user_created
  ON analysis_refunds(user_id, refunded_at DESC);

ALTER TABLE analysis_refunds ENABLE ROW LEVEL SECURITY;

-- Users have NO access. The table is service-role-only audit storage.
-- Each policy is explicit per CRUD to match the project's RLS hygiene
-- discipline (see docs/reports/phase1a-db-plan.md §4).
CREATE POLICY analysis_refunds_select_deny ON analysis_refunds
  FOR SELECT
  TO authenticated
  USING (false);

CREATE POLICY analysis_refunds_insert_deny ON analysis_refunds
  FOR INSERT
  TO authenticated
  WITH CHECK (false);

CREATE POLICY analysis_refunds_update_deny ON analysis_refunds
  FOR UPDATE
  TO authenticated
  USING (false);

CREATE POLICY analysis_refunds_delete_deny ON analysis_refunds
  FOR DELETE
  TO authenticated
  USING (false);

COMMENT ON TABLE analysis_refunds IS
  'Append-only audit of free-tier quota refunds issued by the analyze edge function.';

-- =============================================================================
-- refund_free_analysis(p_user_id, p_request_id, p_reason)
-- =============================================================================
-- Returns boolean:
--   true   — the refund was newly recorded (counter may or may not have
--            been decremented; subscribers + zero-quota users see true but
--            no counter change)
--   false  — this request_id was already refunded (idempotent no-op)
--
-- Raises 'user_not_found' if the user doesn't exist (should not happen in
-- normal flow; the edge function only refunds users who just consumed
-- quota).
-- =============================================================================

CREATE OR REPLACE FUNCTION refund_free_analysis(
  p_user_id    uuid,
  p_request_id text,
  p_reason     text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text;
  v_used   int;
BEGIN
  IF p_request_id IS NULL OR length(p_request_id) = 0 THEN
    RAISE EXCEPTION 'request_id_required' USING ERRCODE = 'P0001';
  END IF;

  -- Audit insert. UNIQUE on request_id is what makes this idempotent.
  BEGIN
    INSERT INTO analysis_refunds (user_id, request_id, reason)
    VALUES (p_user_id, p_request_id, p_reason);
  EXCEPTION
    WHEN unique_violation THEN
      RETURN false;
    WHEN check_violation THEN
      -- p_reason violated the CHECK constraint.
      RAISE EXCEPTION 'invalid_reason' USING ERRCODE = 'P0001';
  END;

  -- Lock the user row so concurrent consume + refund can't race.
  SELECT subscription_status, free_analyses_used_this_month
    INTO v_status, v_used
    FROM users
   WHERE id = p_user_id
     FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0002';
  END IF;

  -- Subscribers never consumed quota in the first place.
  -- Free users with v_used = 0 have nothing to refund.
  IF v_status = 'free' AND v_used > 0 THEN
    UPDATE users
       SET free_analyses_used_this_month = v_used - 1
     WHERE id = p_user_id;
  END IF;

  RETURN true;
END;
$$;

COMMENT ON FUNCTION refund_free_analysis(uuid, text, text) IS
  'Atomic refund of one free-tier slot. Idempotent via UNIQUE on request_id. Service role only.';

REVOKE ALL ON FUNCTION refund_free_analysis(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION refund_free_analysis(uuid, text, text) FROM anon;
REVOKE ALL ON FUNCTION refund_free_analysis(uuid, text, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION refund_free_analysis(uuid, text, text) TO service_role;
