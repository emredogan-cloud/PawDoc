-- =============================================================================
-- Phase 1A — referrals
-- =============================================================================
-- Personal referral codes. The user creates a code; when a referred friend
-- subscribes, the service role flips `converted = true` (the user must NOT
-- be able to game this).
-- =============================================================================

CREATE TABLE referrals (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  referred_email      text,
  referral_code       text NOT NULL UNIQUE,
  converted           bool NOT NULL DEFAULT false,
  converted_at        timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT referrals_code_format
    CHECK (length(referral_code) BETWEEN 4 AND 64),
  -- converted_at presence is consistent with converted=true.
  CONSTRAINT referrals_converted_consistency
    CHECK ((converted = false AND converted_at IS NULL)
        OR (converted = true  AND converted_at IS NOT NULL))
);

CREATE INDEX idx_referrals_referrer ON referrals(referrer_user_id);
-- referral_code uniqueness comes from the UNIQUE constraint; no extra index.

-- ---------------------------------------------------------------------------
-- RLS — owner can SELECT/INSERT; only service role mutates conversion.
-- ---------------------------------------------------------------------------
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

CREATE POLICY referrals_select_own ON referrals
  FOR SELECT
  TO authenticated
  USING (auth.uid() = referrer_user_id);

CREATE POLICY referrals_insert_own ON referrals
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = referrer_user_id
    AND converted = false
    AND converted_at IS NULL
  );

-- UPDATE: deny user-facing. converted/converted_at are service-role flipped.
CREATE POLICY referrals_update_deny ON referrals
  FOR UPDATE
  TO authenticated
  USING (false);

CREATE POLICY referrals_delete_deny ON referrals
  FOR DELETE
  TO authenticated
  USING (false);

COMMENT ON TABLE referrals IS
  'Personal referral codes. converted/converted_at are written by the service role only.';
