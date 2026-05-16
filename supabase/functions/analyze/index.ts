// =============================================================================
// /analyze — submit a pet health analysis request.
// =============================================================================
// Phase 1B: end-to-end flow.
//
//   1. CORS preflight
//   2. require user JWT
//   3. validate body
//   4. confirm caller owns the pet (RLS-gated SELECT under user JWT)
//   5. emergency keyword scan (quota-bypass advisory)
//   6. daily rate limit (Upstash; SKIPPED on emergency)
//   7. free-tier consume RPC (SKIPPED on emergency)
//   8. load full pet context (service-role read)
//   9. call ai-service /analyze (X-Internal-Token, X-Request-ID)
//  10. validate response shape
//  11. INSERT into analyses (service role; append-only by RLS)
//  12. return result
//
// The mobile app sees a structured AnalysisResult for every legitimate
// request — even when AI providers fail (graceful_degradation on the AI
// service side).
// =============================================================================

import { preflight, resolveOrigin } from "../_shared/cors.ts";
import { ApiError, Errors, withErrorHandler } from "../_shared/errors.ts";
import { log } from "../_shared/logger.ts";
import { requireUser } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabase-admin.ts";
import { supabaseUser } from "../_shared/supabase-user.ts";
import {
  asObject,
  asOneOf,
  asOptional,
  asString,
  asUuid,
  readJson,
} from "../_shared/validation.ts";
import { checkEmergencyOverride } from "../_shared/emergency.ts";
import { getDailyLimiter } from "../_shared/rate-limit.ts";
import {
  AiServicePet,
  AiServiceRequest,
  AiServiceResult,
  callAiService,
} from "../_shared/ai-service.ts";

const INPUT_TYPES = ["photo", "video", "text"] as const;
type InputType = (typeof INPUT_TYPES)[number];

// Sprint B2 abuse hardening:
//   - Hard cap on owner-supplied text so a 50 KB prompt-injection
//     payload can't burn tokens upstream.
//   - Storage-key shape gate before we let the AI service mint a URL
//     for it. Rejects `../` traversal, absolute paths, and the empty
//     filename suffix that some manual cURL clients send.
const TEXT_DESCRIPTION_MAX_CHARS = 2000;
const STORAGE_KEY_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/[A-Za-z0-9._-]{1,128}$/i;

interface AnalyzeRequest {
  petId: string;
  inputType: InputType;
  inputStorageKey?: string;
  textDescription?: string;
}

/**
 * Strip ASCII control characters that have no business inside a
 * symptom description. Whitespace (`\t`, `\n`, `\r`) is preserved
 * because owners legitimately paste multi-line notes; everything else
 * in the `\x00-\x1F` / `\x7F` ranges is removed. This also kills the
 * NUL-byte trick that smuggles around naive `String.length` checks.
 */
function sanitizeTextDescription(raw: string): string {
  // deno-lint-ignore no-control-regex
  return raw.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "");
}

function parseAnalyzeRequest(body: unknown): AnalyzeRequest {
  const obj = asObject(body);
  const petId = asUuid(obj.pet_id, "pet_id");
  const inputType = asOneOf(obj.input_type, INPUT_TYPES, "input_type");
  const inputStorageKey = asOptional(obj.input_storage_key, asString, "input_storage_key");
  const rawText = asOptional(obj.text_description, asString, "text_description");

  let textDescription: string | undefined;
  if (rawText !== undefined) {
    const cleaned = sanitizeTextDescription(rawText).trim();
    if (cleaned.length === 0) {
      // Treat whitespace-only text as "no text supplied" so the
      // input_type=text branch below rejects cleanly.
      textDescription = undefined;
    } else if (cleaned.length > TEXT_DESCRIPTION_MAX_CHARS) {
      throw Errors.validation(
        `text_description must be ${TEXT_DESCRIPTION_MAX_CHARS} characters or fewer.`,
      );
    } else {
      textDescription = cleaned;
    }
  }

  if (inputType === "text" && !textDescription) {
    throw Errors.validation("text_description is required when input_type='text'.");
  }
  if ((inputType === "photo" || inputType === "video") && !inputStorageKey) {
    throw Errors.validation(
      "input_storage_key is required when input_type='photo' or 'video'.",
    );
  }
  if (inputStorageKey !== undefined && !STORAGE_KEY_PATTERN.test(inputStorageKey)) {
    throw Errors.validation(
      "input_storage_key has an invalid shape.",
    );
  }
  return { petId, inputType, inputStorageKey, textDescription };
}

function generateRequestId(): string {
  return crypto.randomUUID();
}

function presignedR2Url(storageKey: string | undefined): string | null {
  // Phase 1B: we forward the storage key as a URL via R2's public base.
  // Phase 1C wires a real presigned-URL minter via R2 with short TTL.
  if (!storageKey) return null;
  const base = Deno.env.get("R2_PUBLIC_BASE_URL");
  if (!base) return null;
  return `${base}/${storageKey}`;
}

/**
 * Read enough pet context to build a useful AI prompt. Uses the SERVICE
 * ROLE because we want every field including chronic conditions etc.,
 * even ones the user's RLS view might omit in the future.
 */
async function loadPetForAi(petId: string): Promise<AiServicePet> {
  const admin = supabaseAdmin();
  const { data, error } = await admin
    .from("pets")
    .select("id, name, species, breed, birth_date, sex, weight_kg")
    .eq("id", petId)
    .maybeSingle();

  if (error) {
    log.error("pets_load_failed", { code: error.code });
    throw Errors.upstream("Database error.");
  }
  if (!data) {
    throw Errors.notFound("Pet not found.");
  }

  const ageYears = data.birth_date
    ? Math.max(
      0,
      (Date.now() - new Date(data.birth_date).getTime()) /
        (1000 * 60 * 60 * 24 * 365.25),
    )
    : null;

  return {
    pet_id: data.id,
    name: data.name,
    species: data.species as AiServicePet["species"],
    breed: data.breed,
    age_years: ageYears !== null ? Number(ageYears.toFixed(1)) : null,
    sex: (data.sex as AiServicePet["sex"] | null) ?? null,
    weight_kg: data.weight_kg,
    conditions: [],
  };
}

async function persistAnalysis(args: {
  user_id: string;
  pet_id: string;
  input_type: InputType;
  input_storage_key: string | null;
  text_description: string | null;
  result: AiServiceResult;
}): Promise<string> {
  const admin = supabaseAdmin();
  const { data, error } = await admin
    .from("analyses")
    .insert({
      pet_id: args.pet_id,
      user_id: args.user_id,
      input_type: args.input_type,
      input_storage_key: args.input_storage_key,
      text_description: args.text_description,
      triage_level: args.result.triage_level,
      primary_concern: args.result.primary_concern,
      // The Json type is the recursive union from the generated db types;
      // our typed result is structurally compatible — JSON-roundtrip to
      // satisfy the type checker without lying about the runtime value.
      full_response: JSON.parse(JSON.stringify(args.result)),
      model_used: args.result.model_used,
      tier_used: args.result.tier_used,
      confidence_score: args.result.confidence,
      ai_latency_ms: args.result.ai_latency_ms,
      emergency_override_applied: args.result.emergency_override_applied,
    })
    .select("id")
    .single();

  if (error || !data) {
    log.error("analyses_insert_failed", { code: error?.code });
    throw Errors.upstream("Failed to persist analysis.");
  }
  return data.id;
}

/**
 * Refund a free-tier quota slot on AI / persist failure.
 *
 * Best-effort: we never let a refund failure mask the original error.
 * Idempotent: the RPC's UNIQUE on request_id ensures retries don't
 * double-refund. Subscribers + emergency-override paths short-circuit
 * (they never consumed quota to begin with).
 */
async function refundIfQuotaConsumed(
  userId: string,
  requestId: string,
  reason: "ai_failure" | "persist_failure" | "timeout",
  emergencyMatched: boolean,
): Promise<void> {
  if (emergencyMatched) return;
  try {
    const { error } = await supabaseAdmin().rpc("refund_free_analysis", {
      p_user_id: userId,
      p_request_id: requestId,
      p_reason: reason,
    });
    if (error) {
      log.error("quota_refund_rpc_error", {
        request_id: requestId,
        reason,
        code: error.code,
      });
      return;
    }
    log.info("quota_refunded", { request_id: requestId, reason });
  } catch (err) {
    log.error("quota_refund_failed", {
      request_id: requestId,
      reason,
      error: (err as Error).message,
    });
  }
}

const handler = withErrorHandler(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return preflight(req.headers.get("Origin"));
  }
  if (req.method !== "POST") {
    throw Errors.validation("Method not allowed.");
  }

  const requestId = generateRequestId();
  const user = await requireUser(req);

  const body = await readJson(req);
  const payload = parseAnalyzeRequest(body);

  // Step 4 — pet ownership via RLS-gated read.
  const userClient = supabaseUser(req);
  const { data: petCheck, error: petErr } = await userClient
    .from("pets")
    .select("id, is_active")
    .eq("id", payload.petId)
    .maybeSingle();
  if (petErr) {
    log.error("pets_ownership_lookup_failed", {
      code: petErr.code,
      request_id: requestId,
    });
    throw Errors.upstream("Database error.");
  }
  if (!petCheck) {
    throw Errors.notFound("Pet not found.");
  }
  if (!petCheck.is_active) {
    throw Errors.validation("Cannot analyze an inactive pet.");
  }

  // Step 5 — emergency keyword scan (advisory; quota-bypass decisioning).
  const emergency = checkEmergencyOverride(payload.textDescription);
  if (emergency.matched) {
    log.info("emergency_keyword_match", {
      fn: "analyze",
      request_id: requestId,
      user_id: user.id,
      keyword: emergency.keyword,
    });
  }

  // Steps 6-7 — quota gates (skipped on emergency).
  if (!emergency.matched) {
    const rl = await getDailyLimiter().check(user.id);
    log.info("rate_limit_check", {
      fn: "analyze",
      request_id: requestId,
      allowed: rl.allowed,
      remaining: rl.remaining,
      mode: rl.mode,
    });
    if (!rl.allowed) {
      throw Errors.rateLimited(
        `Daily limit reached. Resets at ${rl.resetAtIso}.`,
      );
    }

    const { data: quotaAllowed, error: rpcErr } = await supabaseAdmin().rpc(
      "attempt_consume_free_analysis",
      { p_user_id: user.id, p_monthly_limit: 3 },
    );
    if (rpcErr) {
      log.error("free_tier_rpc_failed", {
        code: rpcErr.code,
        request_id: requestId,
      });
      throw Errors.upstream("Quota check failed.");
    }
    if (quotaAllowed === false) {
      throw new ApiError(
        402,
        "payment_required",
        "Free-tier analyses for this month are used up. Upgrade to continue.",
      );
    }
    log.info("free_tier_consume", {
      fn: "analyze",
      request_id: requestId,
      allowed: true,
    });
  }

  // Step 8 — load pet context for the AI service.
  const aiPet = await loadPetForAi(payload.petId);

  // Step 9 — call the AI service.
  const aiRequest: AiServiceRequest = {
    request_id: requestId,
    pet: aiPet,
    input_type: payload.inputType,
    input_storage_url: presignedR2Url(payload.inputStorageKey),
    text_description: payload.textDescription ?? null,
  };
  log.info("ai_service_call_start", { fn: "analyze", request_id: requestId });
  const t0 = performance.now();
  let result: AiServiceResult;
  try {
    result = await callAiService(aiRequest);
  } catch (err) {
    await refundIfQuotaConsumed(user.id, requestId, "ai_failure", emergency.matched);
    throw err;
  }
  log.info("ai_service_call_end", {
    fn: "analyze",
    request_id: requestId,
    triage_level: result.triage_level,
    tier_used: result.tier_used,
    latency_ms: Math.round(performance.now() - t0),
  });

  // Step 11 — persist (append-only by RLS; we use the service role).
  let analysisId: string;
  try {
    analysisId = await persistAnalysis({
      user_id: user.id,
      pet_id: payload.petId,
      input_type: payload.inputType,
      input_storage_key: payload.inputStorageKey ?? null,
      text_description: payload.textDescription ?? null,
      result,
    });
  } catch (err) {
    await refundIfQuotaConsumed(user.id, requestId, "persist_failure", emergency.matched);
    throw err;
  }
  log.info("analysis_persisted", {
    fn: "analyze",
    request_id: requestId,
    analysis_id: analysisId,
  });

  // Step 12 — return.
  const origin = resolveOrigin(req.headers.get("Origin")) ?? "*";
  return new Response(JSON.stringify({ ...result, analysis_id: analysisId }), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": origin,
      Vary: "Origin",
      "X-Request-ID": requestId,
    },
  });
});

Deno.serve((req: Request) => Promise.resolve(handler(req)));
