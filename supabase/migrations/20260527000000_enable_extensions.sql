-- Phase 0.2 — Core Data & Storage Platform
-- Enable required Postgres extensions BEFORE any schema migration (Phase 1.1 depends on these).
--   uuid-ossp : uuid_generate_v4() for primary keys
--   vector    : pgvector — embedding vector(1536) for the semantic cache (populated in Phase 3.2)
--
-- Installed into the dedicated `extensions` schema per Supabase convention. That schema is
-- already on the API search_path (see config.toml -> [api].extra_search_path = [..., "extensions"]).
-- This migration is the canonical source of truth; `supabase db push` applies it to each project.

create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists vector with schema extensions;
