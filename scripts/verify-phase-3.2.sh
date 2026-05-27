#!/usr/bin/env bash
# =============================================================================
# verify-phase-3.2.sh — Video Analysis Pipeline + Semantic Cache checklist.
# Structural checks (model pins CR#17, frame plumbing, cache wiring, analytics)
# plus the real test batteries when toolchains are present: ruff + pytest, node
# --test, the pgvector semantic-cache test (Docker), and flutter analyze/test.
# Device video capture + live multimodal Gemini + P95 latency stay MANUAL.
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI="$ROOT/ai-service/app"
M="$ROOT/mobile/lib/src"
FN="$ROOT/supabase/functions"

fails=0
pass()   { printf '\033[0;32mPASS\033[0m  %s\n' "$*"; }
fail()   { printf '\033[0;31mFAIL\033[0m  %s\n' "$*"; fails=$((fails+1)); }
manual() { printf '\033[0;34mMANUAL\033[0m %s\n' "$*"; }
hr()     { printf -- '----------------------------------------------------------------\n'; }
check()  { if grep -qiE "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }
have()   { if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1 missing)"; fi; }

hr; echo "Phase 3.2 — Video Analysis Pipeline & Semantic Cache"; hr

# --- Files present -----------------------------------------------------------
have "$ROOT/supabase/migrations/20260527020000_semantic_cache.sql" "match_analyses migration"
have "$ROOT/supabase/tests/semantic_cache.sql"                     "semantic-cache safety test"
have "$ROOT/scripts/test-semantic-cache.sh"                        "semantic-cache test harness"
have "$AI/embeddings.py"                                           "AI embeddings provider"
have "$FN/_shared/semantic_cache.mjs"                              "Edge semantic-cache helpers"
have "$M/capture/keyframe_extractor.dart"                          "Flutter keyframe extractor"
have "$M/capture/video_capture_screen.dart"                        "Flutter video capture screen"

# --- Model pins (CR #17) -----------------------------------------------------
check "VIDEO_MODEL pinned to gemini-2.0-flash" 'VIDEO_MODEL.*gemini-2.0-flash' "$AI/config.py"
check "EMBEDDING_MODEL pinned"                 'EMBEDDING_MODEL' "$AI/config.py"
check "EMBEDDING_DIM = 1536 (matches schema)"  'EMBEDDING_DIM = 1536' "$AI/config.py"
check "SEMANTIC_CACHE_THRESHOLD = 0.90"        'SEMANTIC_CACHE_THRESHOLD = 0.90' "$AI/config.py"
check "GeminiProvider routes video to the pinned model" 'select_model' "$AI/providers.py"

# --- Video frame plumbing ----------------------------------------------------
check "AnalyzeRequest carries frame_urls"     'frame_urls' "$AI/models.py"
check "Pipeline passes frames to the provider" 'request.frame_urls' "$AI/pipeline.py"
check "Edge presigns frame_storage_keys"      'frame_storage_keys' "$FN/analyze/index.ts"
check "analysis_service sends frame_storage_keys" 'frame_storage_keys' "$M/analysis/analysis_service.dart"

# --- Semantic cache safety wiring --------------------------------------------
check "RPC: same-species hard guard"          'lower\(p.species\) = lower\(match_species\)' "$ROOT/supabase/migrations/20260527020000_semantic_cache.sql"
check "RPC: same-user filter"                 'a.user_id = match_user_id' "$ROOT/supabase/migrations/20260527020000_semantic_cache.sql"
check "RPC: NULL embeddings ignored"          'a.embedding is not null' "$ROOT/supabase/migrations/20260527020000_semantic_cache.sql"
check "RPC: locked to service_role"           'grant execute on function' "$ROOT/supabase/migrations/20260527020000_semantic_cache.sql"
check "Edge: cache is text-only / non-emergency" 'isCacheEligible' "$FN/analyze/index.ts"
check "Edge: only text rows store an embedding"  'embedding: embeddingLiteral' "$FN/analyze/index.ts"
check "Edge: calls the embedding endpoint"    '/embed' "$FN/analyze/index.ts"
check "AI: /embed endpoint exists"            '@app.post\("/embed"\)' "$AI/main.py"

# --- Analytics ---------------------------------------------------------------
check "Analytics: video_analysis_submitted"   'video_analysis_submitted' "$M/analytics/analytics.dart"

# --- Keyframe package choice (documented) ------------------------------------
check "video_thumbnail dep (no ffmpeg/GPL)"    'video_thumbnail' "$ROOT/mobile/pubspec.yaml"

# --- AI service: ruff + pytest -----------------------------------------------
if [ -x "$ROOT/ai-service/.venv/bin/python" ]; then
  if (cd "$ROOT/ai-service" && .venv/bin/ruff check . >/tmp/pawdoc_ruff32.log 2>&1); then
    pass "ruff clean"
  else
    fail "ruff issues (see /tmp/pawdoc_ruff32.log)"
  fi
  if (cd "$ROOT/ai-service" && .venv/bin/python -m pytest -q >/tmp/pawdoc_pytest32.log 2>&1); then
    pass "pytest green"
  else
    fail "pytest failed (see /tmp/pawdoc_pytest32.log)"
  fi
else
  manual "Run ruff + pytest from ai-service/ (.venv not found here)."
fi

# --- Edge shared logic: node --test ------------------------------------------
if command -v node >/dev/null 2>&1; then
  if node --test "$FN"/_shared/*.test.mjs >/tmp/pawdoc_node32.log 2>&1; then
    pass "node --test (_shared) green"
  else
    fail "node --test failed (see /tmp/pawdoc_node32.log)"
  fi
else
  manual "Run node --test supabase/functions/_shared/*.test.mjs"
fi

# --- pgvector semantic-cache safety test (Docker) ----------------------------
if command -v docker >/dev/null 2>&1; then
  if "$ROOT/scripts/test-semantic-cache.sh" >/tmp/pawdoc_semcache32.log 2>&1; then
    pass "semantic-cache RPC test green (species/user/threshold/NULL + lockdown)"
  else
    fail "semantic-cache test failed (see /tmp/pawdoc_semcache32.log)"
  fi
else
  manual "Run ./scripts/test-semantic-cache.sh (needs Docker)."
fi

# --- Flutter analyze + test --------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  if (cd "$ROOT/mobile" && flutter analyze >/tmp/pawdoc_an32.log 2>&1); then
    pass "flutter analyze clean"
  else
    fail "flutter analyze issues (see /tmp/pawdoc_an32.log)"
  fi
  if (cd "$ROOT/mobile" && flutter test >/tmp/pawdoc_tt32.log 2>&1); then
    pass "flutter test green"
  else
    fail "flutter test failed (see /tmp/pawdoc_tt32.log)"
  fi
else
  manual "Run flutter analyze + flutter test from mobile/."
fi

# --- MANUAL (device / live infra) --------------------------------------------
manual "On device: record a ≤30s video; confirm 4–6 keyframes extract + upload and a result returns."
manual "Confirm video analysis P95 < 15s on 4G (live Gemini + frame upload) — founder measurement."
manual "With live keys: confirm /embed returns a 1536-dim vector and a repeat text query is a cache hit."
manual "Deno typecheck of the Edge Function (supabase CI) — deno not run here."

hr
if [ "$fails" -eq 0 ]; then
  echo "Phase 3.2 verifiable checks GREEN."; exit 0
else
  echo "$fails check(s) FAILED."; exit 1
fi
