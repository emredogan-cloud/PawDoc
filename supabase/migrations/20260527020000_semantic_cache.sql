-- Phase 3.2 — Semantic cache RPC (pays off the Phase 1 embedding debt).
--
-- match_analyses() finds a near-duplicate PRIOR analysis to serve from cache
-- instead of calling the LLM again. Safety/accuracy guarantees baked into the
-- query itself (not left to the embedding alone):
--   * SAME USER  — a.user_id = match_user_id (privacy: never serve one user's
--                  stored analysis to another; respects the RLS philosophy).
--   * SAME SPECIES — lower(p.species) = lower(match_species). HARD guard so a
--                  Dog query can NEVER return a Bird's cached analysis (CR
--                  "cache safety"). Species lives on pets, hence the join.
--   * NON-NULL embedding — historical rows predating the embedding pipeline are
--                  ignored gracefully (no error, just not a candidate).
--   * THRESHOLD — cosine similarity >= match_threshold (the Edge Function passes
--                  0.90); ordered closest-first.
--
-- The embedding column + ivfflat cosine index already exist (Phase 1.1 schema).
-- `<=>` is pgvector's cosine-distance operator; it lives in the `extensions`
-- schema, so we pin search_path to resolve it.
--
-- Lockdown: only the service role (the Edge Function) may call this. Revoking
-- from anon/authenticated stops an end user from probing another user's cache
-- by passing an arbitrary match_user_id through PostgREST.

create or replace function public.match_analyses(
  query_embedding extensions.vector(1536),
  match_user_id uuid,
  match_species text,
  match_threshold double precision,
  match_count integer
)
returns table (
  id uuid,
  full_response jsonb,
  triage_level text,
  confidence_score numeric,
  similarity double precision
)
language sql
stable
set search_path = public, extensions
as $$
  select
    a.id,
    a.full_response,
    a.triage_level,
    a.confidence_score,
    1 - (a.embedding <=> query_embedding) as similarity
  from public.analyses a
  join public.pets p on p.id = a.pet_id
  where a.embedding is not null
    and a.user_id = match_user_id
    and lower(p.species) = lower(match_species)
    and (1 - (a.embedding <=> query_embedding)) >= match_threshold
  order by a.embedding <=> query_embedding
  limit greatest(match_count, 1);
$$;

revoke all on function
  public.match_analyses(extensions.vector, uuid, text, double precision, integer)
  from public, anon, authenticated;
grant execute on function
  public.match_analyses(extensions.vector, uuid, text, double precision, integer)
  to service_role;
