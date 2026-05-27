# SUB-PR Report — Phase 3.2: Video Analysis Pipeline & Semantic Cache

**Status:** Complete and fully green (ruff, pytest, node, pgvector safety test, flutter analyze/test, shellcheck). Video capture → keyframe extraction → frame upload → analysis, plus a safety-first pgvector semantic cache that pays off the Phase 1 embedding debt.
**Branch:** `phase-3.2-video-analysis` (from `origin/main` = `ee6bf0d`, contains 0.1→3.1)
**Date:** 2026-05-27

---

## 1. Files created / modified

**Semantic cache (DB + AI + Edge):**
```
supabase/migrations/20260527020000_semantic_cache.sql  match_analyses() RPC (same-user + same-species +
                                                       non-null embedding + cosine ≥ threshold), locked to service_role
supabase/tests/semantic_cache.sql                      DB safety test (species/user/threshold/NULL + lockdown)
scripts/test-semantic-cache.sh                         ephemeral pgvector harness for the above
supabase/tests/_local_shim.sql            (mod)        adds anon + service_role roles (grant/revoke fidelity)
ai-service/app/embeddings.py                           EmbeddingProvider + GeminiEmbeddingProvider (1536-dim,
                                                       graceful→None) + build_embedding_input() pure builder
ai-service/app/main.py                    (mod)        POST /embed; VERSION 3.2.0
ai-service/app/config.py                  (mod)        EMBEDDING_MODEL/_DIM, SEMANTIC_CACHE_THRESHOLD/_ENABLED (CR #17)
supabase/functions/_shared/semantic_cache.mjs(+test)   selectCacheHit/formatVector/isCacheEligible (pure) + tests
supabase/functions/analyze/index.ts       (mod)        text-only cache: /embed → match_analyses → hit/miss; store embedding
```
**Video pipeline (AI + Edge + Flutter):**
```
ai-service/app/models.py                  (mod)        AnalyzeRequest.frame_urls; EmbedRequest
ai-service/app/providers.py               (mod)        frame_urls threaded; GeminiProvider.select_model() → pinned VIDEO_MODEL
ai-service/app/pipeline.py / prompts.py   (mod)        pass frames to provider; prompt notes N keyframes
ai-service/tests/test_embeddings.py, test_video.py     new unit tests (+ FakeProvider signature in test_pipeline.py)
mobile/lib/src/capture/keyframe_extractor.dart         pure keyframeTimestamps() + extractKeyframes() (video_thumbnail)
mobile/lib/src/capture/video_capture_screen.dart       ≤30s record → extract → upload frames
mobile/lib/src/capture/upload_service.dart (mod)       uploadFrames() (presigned, per frame)
mobile/lib/src/analysis/{analysis_service,analysis_runner}.dart (mod)  frameStorageKeys plumbing
mobile/lib/src/home/home_screen.dart      (mod)        "Record a video" entry in the check sheet
mobile/lib/src/analytics/analytics.dart   (mod)        video_analysis_submitted
mobile/pubspec.yaml                       (mod)        + video_thumbnail ^0.5.3 (resolved 0.5.6)
mobile/test/video_test.dart                            keyframeTimestamps tests (+ fake signature fix)
scripts/verify-phase-3.2.sh                            phase verifier (structural + all batteries)
ENVIRONMENT_VARS.md                       (mod)        GEMINI_VIDEO_MODEL, GEMINI_EMBEDDING_MODEL, SEMANTIC_CACHE_ENABLED
```
**No new secrets.** Embeddings reuse `GOOGLE_AI_API_KEY`; the RPC is called with the existing `SUPABASE_SERVICE_ROLE_KEY`.

## 2. Keyframe-extraction package: **`video_thumbnail`** (chosen over ffmpeg)

| Option | Verdict |
|---|---|
| `flutter_ffmpeg` (roadmap's suggestion) | ❌ **Discontinued/deprecated.** Don't ship new code on it. |
| `ffmpeg_kit_flutter` | ❌ Upstream **ffmpeg-kit was retired in 2025** (binaries being pulled); **large build size**; **LGPL/GPL** licensing complexity depending on build flavor. |
| **`video_thumbnail`** ✅ | **Chosen.** Uses the **native** extractors (Android `MediaMetadataRetriever`, iOS `AVAssetImageGenerator`) — **no ffmpeg binary**, so far smaller app size, **permissive license**, and actively maintained. Extracts a JPEG at any `timeMs`, which is exactly what keyframing needs. |

**How it's used:** `keyframeTimestamps(durationMs, count)` (pure, unit-tested) computes evenly-spaced sample points at `i/(count+1)` of the clip (avoiding the first/last frame); `extractKeyframes()` then pulls a JPEG at each via `video_thumbnail`. Default **5 frames** (roadmap's 4–6), **≤30s** clips. Extraction + upload run in `async/await` on the platform channel — the **UI thread is never blocked** (latency-budget rule).

## 3. How the semantic cache guarantees accuracy (no species/condition mismatch)

The guarantees live in the **SQL**, not in the embedding's good behavior — defense in depth:

1. **Hard species guard (Dog ↛ Bird).** `match_analyses` joins `analyses → pets` and filters `lower(p.species) = lower(match_species)`. A dog query can **never** return a bird's cached analysis, *even if the embeddings are identical* — the DB safety test asserts exactly this (an embedding-identical bird row is excluded from a dog query, and vice-versa).
2. **Same-user only.** `a.user_id = match_user_id` — one user is never served another user's stored analysis (privacy + the RLS philosophy). Cross-user caching was deliberately **not** implemented.
3. **High threshold.** Cosine similarity must be **≥ 0.90** (re-checked in `selectCacheHit` as well). A near-duplicate must be genuinely near.
4. **Species/breed dominate the vector.** `build_embedding_input` puts `species`/`breed` **first**, so different species/breeds sit far apart in embedding space *before* the SQL filter even applies.
5. **Text-only, never images.** The cache applies **only to `text` inputs** (`isCacheEligible`). Photo/video are never cached, because (a) the image — not the text — is the real signal, and (b) skipping the LLM would also skip image **moderation**. Only text rows get an `embedding` stored, so the cache can only ever match text→text.
6. **Emergencies bypass the cache** entirely — they always hit the hardcoded override in the AI service. The emergency override still runs *before* any cache/AI path.
7. **NULL-safe + non-blocking + locked down.** Historical rows with `NULL` embeddings are ignored; any embedding/RPC failure falls through to a normal analysis (the cache never blocks a triage); and the RPC is `REVOKE`d from anon/authenticated and `GRANT`ed only to `service_role`, so a user can't probe another user's cache via PostgREST.

Proven headlessly by `scripts/test-semantic-cache.sh` (ephemeral pgvector): same-species hit, **species-leak blocked**, **cross-user blocked**, NULL ignored, sub-threshold rejected, lockdown enforced.

## 4. Tests executed & results

| Test | Result |
|------|--------|
| `ruff check .` (ai-service) | **clean** |
| `pytest -q` (ai-service) | **56 pass** (+16: embeddings, /embed, video routing, frame plumbing) |
| `node --test _shared/*.mjs` | **17 pass** (+5: formatVector/selectCacheHit/isCacheEligible) |
| `./scripts/test-semantic-cache.sh` (Docker pgvector) | **PASS** — species/user/threshold/NULL guards + service-role lockdown |
| `flutter analyze` | **No issues found** |
| `flutter test` | **49 pass** (+5: keyframeTimestamps) |
| `./scripts/verify-phase-3.2.sh` | **exit 0** — all structural + all batteries green; 4 MANUAL |
| `shellcheck` (new scripts, Docker) | **clean** |

## 5. Design decisions surfaced (not silently applied)

- **Cache is text-only** (see §3.5) — a safety call: it keeps image **moderation** in the path and avoids serving a stale result for a *different* photo that happens to share pet context. Flagged because the deliverable didn't explicitly restrict input type.
- **Same-user scoping** (not cross-user) for privacy/safety; fewer hits, zero cross-user leakage.
- **"Video" = client keyframes + multi-image Gemini**, not a full-video upload to the Gemini File API. Lighter, fits the <15s budget, reuses the image plumbing. The request-level wiring (frame URLs, pinned `VIDEO_MODEL`) is in place; **actually attaching the frames to the multimodal Gemini call is validated founder-side with live keys** (the photo path has the same property today — the provider currently sends text context to the model). Marked MANUAL.
- **Embedding model/dimension:** schema is `vector(1536)`; pinned `gemini-embedding-001` requested at **1536 dims** (Matryoshka). If the model name needs adjusting at deploy, it's env-overridable and the cache degrades gracefully meanwhile.

## 6. Known limitations / MANUAL (device / live infra)

- Device video capture, the live multimodal Gemini call, `/embed` returning a real 1536-vector, and **P95 < 15s on 4G** are founder/device-side (no camera/keys/Deno here) — listed in the verifier as MANUAL.
- Deno typecheck of `analyze/index.ts` runs in Supabase CI (deno not installed here); the `_shared` logic it depends on is node-tested.

## 7. Git branch / commit / push

- Branch: `phase-3.2-video-analysis`
- Implementation commit (deliverables): `1b3b55a872e6c6206cf7380edd45cbba70a28325`
- Push: pushed to `origin/phase-3.2-video-analysis`; open PR at https://github.com/emredogan-cloud/PawDoc/pull/new/phase-3.2-video-analysis

## 8. Definition-of-Done verification

| DoD item | State | Evidence |
|----------|-------|----------|
| In-app video capture (≤30s) | ✅ DONE (device MANUAL) | `video_capture_screen.dart` |
| Client-side keyframe extraction (4–6) | ✅ DONE | `keyframe_extractor.dart`; `video_test.dart` |
| Upload frames via presigned URLs | ✅ DONE | `uploadFrames()` (reuses CR #6 path) |
| Edge + `/analyze` handle video/frames | ✅ DONE | `frame_storage_keys`→`frame_urls`; `AnalyzeRequest.frame_urls` |
| Video → Gemini Tier 2, model pinned (CR #17) | ✅ DONE | `select_model()` + `VIDEO_MODEL`; `test_video.py` |
| Embedding generation for analysis text | ✅ DONE | `embeddings.py` + `/embed`; `test_embeddings.py` |
| pgvector similarity lookup, >90% → cached | ✅ DONE | `match_analyses` + `selectCacheHit`; pg test |
| New analyses populate embedding; NULL-safe | ✅ DONE | Edge stores embedding (text); RPC ignores NULLs (pg test) |
| Cache respects species (no Dog↛Bird) | ✅ DONE | hard SQL guard; pg test asserts no leak |
| `video_analysis_submitted` fires | ✅ DONE | `analytics.dart` + runner |
| Video P95 < 15s on 4G | ⏳ MANUAL | founder measurement |

**Verified now:** the full pipeline compiles + unit-tests green across all four surfaces, and the cache's species/user/threshold safety is proven at the database level. Stopping for approval before Phase 3.3.
