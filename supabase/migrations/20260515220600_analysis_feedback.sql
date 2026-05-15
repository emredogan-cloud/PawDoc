-- =============================================================================
-- Phase 1A — analysis_feedback
-- =============================================================================
-- Outcome feedback the user provides 72h after an analysis. Drives the model-
-- training dataset (roadmap §7 Phase 6).
--
-- Append-only from the user's perspective. The 72h follow-up flow inserts;
-- the user cannot then edit or delete (signal must be honest).
-- =============================================================================

CREATE TABLE analysis_feedback (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  analysis_id   uuid NOT NULL REFERENCES analyses(id) ON DELETE CASCADE,
  outcome       text,
  rating        int,
  comment       text,
  created_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT analysis_feedback_outcome_check
    CHECK (outcome IS NULL OR outcome IN (
      'resolved_on_own',
      'vet_confirmed',
      'vet_said_nothing',
      'still_monitoring',
      'other'
    )),
  CONSTRAINT analysis_feedback_rating_range
    CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5)),
  -- At least one signal must be supplied — pure-empty rows are noise.
  CONSTRAINT analysis_feedback_non_empty
    CHECK (outcome IS NOT NULL OR rating IS NOT NULL OR comment IS NOT NULL)
);

CREATE INDEX idx_analysis_feedback_analysis_id ON analysis_feedback(analysis_id);

-- ---------------------------------------------------------------------------
-- RLS — ownership via parent analysis (which holds user_id)
-- ---------------------------------------------------------------------------
ALTER TABLE analysis_feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY analysis_feedback_select_own ON analysis_feedback
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM analyses a
    WHERE a.id = analysis_feedback.analysis_id AND a.user_id = auth.uid()
  ));

CREATE POLICY analysis_feedback_insert_own ON analysis_feedback
  FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM analyses a
    WHERE a.id = analysis_feedback.analysis_id AND a.user_id = auth.uid()
  ));

-- Append-only from user perspective.
CREATE POLICY analysis_feedback_update_deny ON analysis_feedback
  FOR UPDATE
  TO authenticated
  USING (false);

CREATE POLICY analysis_feedback_delete_deny ON analysis_feedback
  FOR DELETE
  TO authenticated
  USING (false);

COMMENT ON TABLE analysis_feedback IS
  '72h outcome feedback on analyses. Append-only from user perspective.';
