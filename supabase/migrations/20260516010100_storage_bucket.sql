-- =============================================================================
-- Phase 1C — pet-uploads storage bucket
-- =============================================================================
-- Private bucket for analyze-flow image uploads. Each user uploads to a
-- folder keyed by their auth.uid(); RLS prevents cross-user reads and
-- writes.
--
-- For Phase 1C this is the canonical storage path. Phase 2 migrates the
-- production bucket to Cloudflare R2 (zero-egress fees per roadmap §3);
-- the schema's `analyses.input_storage_key` field is opaque so the
-- migration is local to the storage layer.
-- =============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pet-uploads',
  'pet-uploads',
  false,                      -- private; signed URLs only
  5242880,                    -- 5 MiB hard cap; client compresses to <2 MB target
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'image/webp'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- RLS — per-user folder
-- ---------------------------------------------------------------------------
-- Convention: storage paths look like `<user_uuid>/<random_name>.jpg`.
-- `storage.foldername(name)` returns the path components as a text array;
-- `(storage.foldername(name))[1]` is the first folder.
-- ---------------------------------------------------------------------------

CREATE POLICY "pet_uploads_select_own" ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'pet-uploads'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "pet_uploads_insert_own" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'pet-uploads'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- UPDATE/DELETE user-facing deny. Service role can still clean up via the
-- bucket admin path (storage.admin). Phase 3 lifecycle policy archives
-- images older than 90 days (roadmap §8 "storage lifecycle").
CREATE POLICY "pet_uploads_update_deny" ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (false);

CREATE POLICY "pet_uploads_delete_deny" ON storage.objects
  FOR DELETE
  TO authenticated
  USING (false);

-- Note: COMMENT ON POLICY ... ON storage.objects is intentionally omitted;
-- the migration runs as `postgres` which lacks ownership of storage.objects
-- on Supabase, and COMMENT requires that ownership. Policy names speak for
-- themselves.
