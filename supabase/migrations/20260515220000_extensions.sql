-- =============================================================================
-- Phase 1A — Extensions
-- =============================================================================
-- All extensions used by the PawDoc schema, enabled idempotently.
-- This file MUST run before any other migration.
--
-- pgcrypto    gen_random_uuid() — default for every PK
-- uuid-ossp   roadmap §10 Phase 0 deliverable; legacy UUID generators
--             (kept enabled for compatibility with libraries that prefer
--             uuid_generate_v4(); gen_random_uuid() is our default)
-- vector      pgvector — analyses.embedding (1536-dim, semantic cache,
--             roadmap §5 + §3)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";
