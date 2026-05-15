-- =============================================================================
-- Phase 1A — analyses
-- =============================================================================
-- The immutable, append-only log of every AI triage analysis the user has
-- ever requested. This table IS the legal record (roadmap §9).
--
-- Critical invariants:
-- 1. Users cannot INSERT/UPDATE/DELETE rows. All writes are via service role
--    (the ai-service). Users can only SELECT their own rows.
-- 2. pet_id has ON DELETE NO ACTION — deleting a pet does NOT delete its
--    analyses. Use is_active=false to tombstone a pet without losing its
--    history. (user_id has CASCADE — full account deletion does drop the
--    user's analyses, satisfying GDPR right-to-deletion.)
-- 3. embedding column is preparation for Phase 3 semantic cache; null until
--    the embedding pipeline ships.
-- =============================================================================

CREATE TABLE analyses (
  id                            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id                        uuid REFERENCES pets(id) ON DELETE NO ACTION,
  user_id                       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  input_type                    text NOT NULL,
  input_storage_key             text,
  text_description              text,
  triage_level                  text,
  primary_concern               text,
  full_response                 jsonb,
  model_used                    text,
  tier_used                     int,
  confidence_score              numeric(4,3),
  ai_latency_ms                 int,
  emergency_override_applied    bool NOT NULL DEFAULT false,
  embedding                     vector(1536),
  created_at                    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT analyses_input_type_check
    CHECK (input_type IN ('photo', 'video', 'text')),
  CONSTRAINT analyses_triage_level_check
    CHECK (triage_level IS NULL
           OR triage_level IN ('EMERGENCY', 'MONITOR', 'NORMAL')),
  CONSTRAINT analyses_tier_used_check
    CHECK (tier_used IS NULL OR tier_used IN (2, 3, 4)),
  CONSTRAINT analyses_confidence_range
    CHECK (confidence_score IS NULL
           OR (confidence_score >= 0 AND confidence_score <= 1)),
  CONSTRAINT analyses_latency_non_negative
    CHECK (ai_latency_ms IS NULL OR ai_latency_ms >= 0)
);

CREATE INDEX idx_analyses_pet_id           ON analyses(pet_id);
CREATE INDEX idx_analyses_user_id_created  ON analyses(user_id, created_at DESC);
CREATE INDEX idx_analyses_triage_level     ON analyses(triage_level);

-- ivfflat — semantic cache lookup (Phase 3). lists=100 per roadmap §5.
-- Note: needs ANALYZE after first significant data load; covered in Phase 3
-- operational docs.
CREATE INDEX idx_analyses_embedding ON analyses
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- ---------------------------------------------------------------------------
-- RLS — append-only from a user's perspective
-- ---------------------------------------------------------------------------
ALTER TABLE analyses ENABLE ROW LEVEL SECURITY;

CREATE POLICY analyses_select_own ON analyses
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Hard-deny writes from the authenticated role. Service role bypasses RLS.
CREATE POLICY analyses_insert_deny ON analyses
  FOR INSERT
  TO authenticated
  WITH CHECK (false);

CREATE POLICY analyses_update_deny ON analyses
  FOR UPDATE
  TO authenticated
  USING (false);

CREATE POLICY analyses_delete_deny ON analyses
  FOR DELETE
  TO authenticated
  USING (false);

COMMENT ON TABLE analyses IS
  'Immutable, append-only log of AI triage analyses. Service-role writes only.';
COMMENT ON COLUMN analyses.pet_id IS
  'No-action on pet delete: analyses must outlive a tombstoned pet (legal record).';
COMMENT ON COLUMN analyses.user_id IS
  'Cascade on user delete: full account deletion drops all analyses (GDPR).';
COMMENT ON COLUMN analyses.embedding IS
  'pgvector(1536) for OpenAI text-embedding-3-small. Populated in Phase 3.';
