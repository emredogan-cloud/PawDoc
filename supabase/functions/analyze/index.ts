// Phase 1.3 — /analyze Edge Function.
// Validates input, loads pet context (RLS-scoped), enforces the free tier
// server-side (with the CR #10 monthly reset), calls the Python AI service
// (propagating a request-id end-to-end, CR #23), stores the result via the
// service role, and returns the AnalysisResult to the client.
//
// verify_jwt is left at its default (true): the app calls this authenticated.
import { createClient } from "jsr:@supabase/supabase-js@2";
// deno-lint-ignore no-import-assertions
import { evaluateFreeTier } from "../_shared/free_tier.mjs";

const AI_SERVICE_URL = Deno.env.get("AI_SERVICE_URL") ?? "https://pawdoc-ai.fly.dev";
const PREMIUM_STATUSES = new Set(["premium", "family", "trial"]);

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
    .select("subscription_status, free_analyses_used_this_month, free_analyses_reset_at")
    .eq("id", user.id).single();
  const isPremium = PREMIUM_STATUSES.has(profile?.subscription_status ?? "free");
  const decision = evaluateFreeTier({
    usedThisMonth: profile?.free_analyses_used_this_month ?? 0,
    resetAt: profile?.free_analyses_reset_at,
    isPremium,
  });
  if (!decision.allowed) {
    return json({
      error: "free_limit_reached",
      message:
        "You've used your free analyses this month. Upgrade for unlimited checks. " +
        "If this seems urgent, contact a veterinarian now.",
    }, 402);
  }

  // Call the AI service, propagating the request-id (CR #23).
  // deno-lint-ignore no-explicit-any
  let ai: any;
  try {
    const resp = await fetch(`${AI_SERVICE_URL}/analyze`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-request-id": requestId },
      body: JSON.stringify({
        input_type,
        text_description: text_description ?? null,
        image_url: image_url ?? null,
        low_input_quality: body.low_input_quality ?? false,
        pet: {
          species: pet.species,
          breed: pet.breed,
          age_years: petAgeYears(pet.birth_date),
          sex: pet.sex,
          weight_kg: pet.weight_kg,
          prior_history: [],
        },
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

  const result = ai.result;
  const meta = ai.meta ?? {};

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
  }).select("id").single();
  if (storeErr) console.error("analyze: failed to store analysis", requestId, storeErr.message);

  // Increment the free-tier counter only after a successful analysis.
  if (!isPremium) {
    await admin.from("users").update({
      free_analyses_used_this_month: decision.newUsed,
      free_analyses_reset_at: decision.resetAt,
    }).eq("id", user.id);
  }

  return json({ result, analysis_id: stored?.id ?? null, request_id: requestId });
});
