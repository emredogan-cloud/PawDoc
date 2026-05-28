// Phase 1.3 — /analyze Edge Function.
// Validates input, loads pet context (RLS-scoped), enforces the free tier
// server-side (with the CR #10 monthly reset), calls the Python AI service
// (propagating a request-id end-to-end, CR #23), stores the result via the
// service role, and returns the AnalysisResult to the client.
//
// verify_jwt is left at its default (true): the app calls this authenticated.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.20";
// deno-lint-ignore no-import-assertions
import { evaluateFreeTier } from "../_shared/free_tier.mjs";
// deno-lint-ignore no-import-assertions
import { containsEmergencyKeyword } from "../_shared/emergency_keywords.mjs";
// deno-lint-ignore no-import-assertions
import { formatVector, isCacheEligible, selectCacheHit } from "../_shared/semantic_cache.mjs";

const AI_SERVICE_URL = Deno.env.get("AI_SERVICE_URL") ?? "https://pawdoc-ai.fly.dev";
const PREMIUM_STATUSES = new Set(["premium", "family", "trial"]);
const SEMANTIC_CACHE_THRESHOLD = 0.90;
const SEMANTIC_CACHE_ENABLED =
  !["0", "false", "no"].includes((Deno.env.get("SEMANTIC_CACHE_ENABLED") ?? "1").toLowerCase());

// Presign a short-lived GET URL so the AI service can read the uploaded image
// (Phase 1.2 stored it and handed the client only the key).
async function presignGet(key: string): Promise<string | null> {
  const accountId = Deno.env.get("R2_ACCOUNT_ID");
  const bucket = Deno.env.get("R2_BUCKET");
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
  if (!accountId || !bucket || !accessKeyId || !secretAccessKey) return null;
  const r2 = new AwsClient({ accessKeyId, secretAccessKey, service: "s3", region: "auto" });
  const u = new URL(`https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`);
  u.searchParams.set("X-Amz-Expires", "120");
  const signed = await r2.sign(new Request(u.toString(), { method: "GET" }), {
    aws: { signQuery: true },
  });
  return signed.url;
}

// Delete an R2 object (used when moderation rejects an upload — CR #8).
async function deleteR2Object(key: string): Promise<void> {
  const accountId = Deno.env.get("R2_ACCOUNT_ID");
  const bucket = Deno.env.get("R2_BUCKET");
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
  if (!accountId || !bucket || !accessKeyId || !secretAccessKey) return;
  const r2 = new AwsClient({ accessKeyId, secretAccessKey, service: "s3", region: "auto" });
  await r2.fetch(`https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`, { method: "DELETE" });
}

// deno-lint-ignore no-explicit-any
function petAgeYears(birthDate: any): number | null {
  if (!birthDate) return null;
  const ms = Date.now() - new Date(birthDate).getTime();
  return Math.max(0, Math.round((ms / (365.25 * 24 * 3600 * 1000)) * 10) / 10);
}

Deno.serve(async (req: Request) => {
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "x-request-id": requestId },
    });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  // RLS-scoped client (acts as the calling user) for reads.
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: auth } = await userClient.auth.getUser();
  const user = auth?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }
  const { pet_id, input_type, text_description, image_url } = body ?? {};
  if (!pet_id || !input_type) return json({ error: "pet_id and input_type are required" }, 400);
  if (!["photo", "video", "text"].includes(input_type)) {
    return json({ error: "invalid input_type" }, 400);
  }

  // Service-role client for the counter + storing results (bypasses RLS by design).
  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

  // Pet must belong to the caller (RLS enforces this on the user-scoped client).
  const { data: pet, error: petErr } = await userClient
    .from("pets").select("*").eq("id", pet_id).single();
  if (petErr || !pet) return json({ error: "pet not found" }, 404);

  // Free-tier evaluation (server-side; CR #10 reset).
  const { data: profile } = await admin
    .from("users")
    .select("subscription_status, free_analyses_used_this_month, free_analyses_reset_at, bonus_analyses")
    .eq("id", user.id).single();
  const isPremium = PREMIUM_STATUSES.has(profile?.subscription_status ?? "free");
  // EMERGENCY IS NEVER PAYWALLED (trust rule): a text tripping an emergency
  // keyword bypasses the free-tier gate entirely and is not counted against
  // the quota. The AI service still runs the authoritative hardcoded override.
  const isEmergencyText = containsEmergencyKeyword(text_description, pet.species);
  const decision = evaluateFreeTier({
    usedThisMonth: profile?.free_analyses_used_this_month ?? 0,
    resetAt: profile?.free_analyses_reset_at,
    isPremium,
    bonus: profile?.bonus_analyses ?? 0, // Phase 3.3 referral reward pool
  });
  if (!isEmergencyText && !decision.allowed) {
    return json({
      error: "free_limit_reached",
      message:
        "You've used your free analyses this month. Upgrade for unlimited checks. " +
        "If this seems urgent, contact a veterinarian now.",
    }, 402);
  }

  // Pet context shared by /embed and /analyze.
  const petPayload = {
    species: pet.species,
    breed: pet.breed,
    age_years: petAgeYears(pet.birth_date),
    sex: pet.sex,
    weight_kg: pet.weight_kg,
    prior_history: [] as string[],
  };

  // Presign a GET URL for the uploaded image (Phase 1.2 produced the key).
  const imageUrl = (image_url as string | null) ??
    (body.input_storage_key ? await presignGet(body.input_storage_key) : null);

  // Video (Phase 3.2): presign each client-extracted keyframe (4–6) so the AI
  // service can read them with short-lived GET URLs.
  const frameKeys: string[] = Array.isArray(body.frame_storage_keys) ? body.frame_storage_keys : [];
  const frameUrls: string[] = [];
  for (const k of frameKeys) {
    const u = await presignGet(k);
    if (u) frameUrls.push(u);
  }

  // deno-lint-ignore no-explicit-any
  let result: any = null;
  // deno-lint-ignore no-explicit-any
  let meta: any = {};
  // Only text inputs get an embedding (stored on the row), so the cache only
  // ever matches text→text — photo/video are never served from cache.
  let embeddingLiteral: string | null = null;
  let cacheHit = false;

  // --- Semantic cache (Phase 3.2) -------------------------------------------
  // Text-only, non-emergency: embed the symptom text + pet context and look for
  // a same-user, same-species near-duplicate (>= 0.90). A hit skips the LLM.
  if (isCacheEligible(input_type, isEmergencyText, SEMANTIC_CACHE_ENABLED)) {
    try {
      const embResp = await fetch(`${AI_SERVICE_URL}/embed`, {
        method: "POST",
        headers: { "content-type": "application/json", "x-request-id": requestId },
        body: JSON.stringify({ text_description: text_description ?? null, pet: petPayload }),
      });
      if (embResp.ok) {
        const emb = await embResp.json();
        embeddingLiteral = formatVector(emb.embedding);
        if (embeddingLiteral) {
          const { data: rows } = await admin.rpc("match_analyses", {
            query_embedding: embeddingLiteral,
            match_user_id: user.id,
            match_species: pet.species,
            match_threshold: SEMANTIC_CACHE_THRESHOLD,
            match_count: 1,
          });
          const hit = selectCacheHit(rows ?? [], SEMANTIC_CACHE_THRESHOLD);
          if (hit) {
            result = hit.full_response;
            meta = {
              model_used: "semantic_cache",
              tier_used: 2,
              cache_hit: true,
              similarity: hit.similarity,
              latency_ms: 0,
            };
            cacheHit = true;
          }
        }
      }
    } catch (_err) {
      // The cache must never break a request — fall through to a fresh analysis.
    }
  }

  // --- Fresh analysis (cache miss / ineligible) ------------------------------
  if (!cacheHit) {
    // deno-lint-ignore no-explicit-any
    let ai: any;
    try {
      const resp = await fetch(`${AI_SERVICE_URL}/analyze`, {
        method: "POST",
        headers: { "content-type": "application/json", "x-request-id": requestId },
        body: JSON.stringify({
          input_type,
          text_description: text_description ?? null,
          image_url: imageUrl,
          frame_urls: frameUrls,
          low_input_quality: body.low_input_quality ?? false,
          pet: petPayload,
        }),
      });
      if (!resp.ok) throw new Error(`AI service returned ${resp.status}`);
      ai = await resp.json();
    } catch (_err) {
      return json({
        error: "analysis_unavailable",
        message: "We can't analyze this right now. If this seems urgent, contact a veterinarian.",
      }, 503);
    }
    result = ai.result;
    meta = ai.meta ?? {};

    // CR #8: moderation rejected the image — delete the stored object, don't persist.
    if (meta.moderation_rejected === true) {
      if (body.input_storage_key) {
        try {
          await deleteR2Object(body.input_storage_key);
        } catch (_err) {
          // best effort
        }
      }
      return json({ result, analysis_id: null, request_id: requestId });
    }
  }

  // Persist the analysis (service role).
  const { data: stored, error: storeErr } = await admin.from("analyses").insert({
    user_id: user.id,
    pet_id,
    input_type,
    input_storage_key: body.input_storage_key ?? null,
    text_description: text_description ?? null,
    triage_level: result.triage_level,
    primary_concern: result.primary_concern,
    full_response: result,
    model_used: meta.model_used,
    tier_used: meta.tier_used,
    confidence_score: result.confidence,
    ai_latency_ms: meta.latency_ms,
    emergency_override_applied: meta.emergency_override_applied ?? false,
    // Phase 3.2: store the embedding (text inputs only) so the semantic cache
    // grows; null for photo/video keeps them out of the cache entirely.
    embedding: embeddingLiteral,
  }).select("id").single();
  if (storeErr) console.error("analyze: failed to store analysis", requestId, storeErr.message);

  // Increment only after a successful, NON-emergency analysis (emergencies are free).
  if (!isPremium && !isEmergencyText) {
    await admin.from("users").update({
      free_analyses_used_this_month: decision.newUsed,
      free_analyses_reset_at: decision.resetAt,
      bonus_analyses: decision.newBonus, // decremented only when a bonus credit was spent
    }).eq("id", user.id);
  }

  return json({ result, analysis_id: stored?.id ?? null, cache_hit: cacheHit, request_id: requestId });
});
