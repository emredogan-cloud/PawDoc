// =============================================================================
// /analyze — submits a pet health analysis request.
// =============================================================================
// Phase 1A scaffold:
//   1. CORS preflight
//   2. require user JWT
//   3. validate request body
//   4. confirm caller owns the pet referenced
//   5. return 501 (Phase 1B wires the ai-service call)
//
// Phase 1B will replace the 501 with:
//   - free-tier consume via attempt_consume_free_analysis()
//   - forward to ai-service POST /analyze with pet context
//   - persist returned analysis row (service role)
//   - return triage result to mobile app
//
// Contract — request body:
//   { pet_id: uuid, input_type: 'photo'|'video'|'text',
//     input_storage_key?: string, text_description?: string }
// =============================================================================

import { preflight, resolveOrigin } from "../_shared/cors.ts";
import { Errors, withErrorHandler } from "../_shared/errors.ts";
import { log } from "../_shared/logger.ts";
import { requireUser } from "../_shared/auth.ts";
import { supabaseUser } from "../_shared/supabase-user.ts";
import {
  asObject,
  asOneOf,
  asOptional,
  asString,
  asUuid,
  readJson,
} from "../_shared/validation.ts";

const INPUT_TYPES = ["photo", "video", "text"] as const;
type InputType = (typeof INPUT_TYPES)[number];

interface AnalyzeRequest {
  petId: string;
  inputType: InputType;
  inputStorageKey?: string;
  textDescription?: string;
}

function parseAnalyzeRequest(body: unknown): AnalyzeRequest {
  const obj = asObject(body);
  const petId = asUuid(obj.pet_id, "pet_id");
  const inputType = asOneOf(obj.input_type, INPUT_TYPES, "input_type");
  const inputStorageKey = asOptional(obj.input_storage_key, asString, "input_storage_key");
  const textDescription = asOptional(obj.text_description, asString, "text_description");

  if (inputType === "text" && !textDescription) {
    throw Errors.validation("text_description is required when input_type='text'.");
  }
  if ((inputType === "photo" || inputType === "video") && !inputStorageKey) {
    throw Errors.validation(
      "input_storage_key is required when input_type='photo' or 'video'.",
    );
  }

  return { petId, inputType, inputStorageKey, textDescription };
}

const handler = withErrorHandler(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return preflight(req.headers.get("Origin"));
  }
  if (req.method !== "POST") {
    throw Errors.validation("Method not allowed.");
  }

  const user = await requireUser(req);
  const body = await readJson(req);
  const payload = parseAnalyzeRequest(body);

  // Ownership check — must succeed under the user's JWT (RLS).
  // If the caller does not own this pet, the SELECT returns zero rows.
  const userClient = supabaseUser(req);
  const { data: pet, error: petErr } = await userClient
    .from("pets")
    .select("id, is_active")
    .eq("id", payload.petId)
    .maybeSingle();

  if (petErr) {
    log.error("pets_lookup_failed", { code: petErr.code });
    throw Errors.upstream("Database error.");
  }
  if (!pet) {
    throw Errors.notFound("Pet not found.");
  }
  if (!pet.is_active) {
    throw Errors.validation("Cannot analyze an inactive pet.");
  }

  log.info("analyze_request_accepted", {
    fn: "analyze",
    user_id: user.id,
    pet_id: payload.petId,
    input_type: payload.inputType,
  });

  // PHASE 1B: replace with free-tier consume + ai-service call + persist.
  throw Errors.notImplemented("Phase 1B");

  // Make TS realise the function technically returns a Response.
  // (Unreachable — Errors.notImplemented throws.)
});

Deno.serve((req: Request): Promise<Response> => {
  const origin = resolveOrigin(req.headers.get("Origin"));
  if (req.method === "OPTIONS" && !origin) {
    return Promise.resolve(new Response(null, { status: 403 }));
  }
  return Promise.resolve(handler(req));
});
