-- =============================================================================
-- Phase 1A — server-side free-tier helpers
-- =============================================================================
-- The free-tier quota MUST be enforced server-side (roadmap §9 + §10 Phase 1
-- task: "Free tier enforcement: check `free_analyses_used_this_month` before
-- AI call; increment after"). The mobile client is never trusted with this.
--
-- This function is the atomic primitive the edge function /analyze will call:
--   - rolls over the monthly counter when the period elapses,
--   - returns true (and increments) if there is quota left,
--   - returns false otherwise (the edge fn then returns 402 PAYMENT_REQUIRED).
--
-- Executed under SECURITY DEFINER so it runs with the table owner's rights
-- regardless of caller. The function is granted ONLY to the service role —
-- the authenticated role cannot invoke it.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.attempt_consume_free_analysis(
  p_user_id uuid,
  p_monthly_limit int DEFAULT 3
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now             timestamptz := now();
  v_period_end      timestamptz;
  v_used            int;
  v_status          text;
BEGIN
  -- Lock the user's row for the duration of the transaction.
  SELECT subscription_status,
         free_analyses_used_this_month,
         free_analyses_reset_at
    INTO v_status, v_used, v_period_end
    FROM public.users
   WHERE id = p_user_id
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0002';
  END IF;

  -- Paying subscribers always have quota — handled by the caller. This
  -- function focuses on the free-tier counter and returns true unconditionally
  -- when status is not 'free'.
  IF v_status <> 'free' THEN
    RETURN true;
  END IF;

  -- Roll over the monthly window if elapsed.
  IF v_now >= v_period_end THEN
    v_used := 0;
    v_period_end := date_trunc('month', v_now) + interval '1 month';
  END IF;

  IF v_used >= p_monthly_limit THEN
    -- Persist the rollover if it happened (so the user sees the new period
    -- start) but do not increment.
    UPDATE public.users
       SET free_analyses_used_this_month = v_used,
           free_analyses_reset_at        = v_period_end
     WHERE id = p_user_id;
    RETURN false;
  END IF;

  UPDATE public.users
     SET free_analyses_used_this_month = v_used + 1,
         free_analyses_reset_at        = v_period_end,
         last_active_at                = v_now
   WHERE id = p_user_id;

  RETURN true;
END;
$$;

COMMENT ON FUNCTION public.attempt_consume_free_analysis(uuid, int) IS
  'Atomic server-side free-tier quota check + increment. Service role only.';

-- Restrict callability to service role. authenticated role gets NO grant.
REVOKE ALL ON FUNCTION public.attempt_consume_free_analysis(uuid, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.attempt_consume_free_analysis(uuid, int) FROM anon;
REVOKE ALL ON FUNCTION public.attempt_consume_free_analysis(uuid, int) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.attempt_consume_free_analysis(uuid, int) TO service_role;
