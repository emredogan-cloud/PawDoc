// Client wrapper for the AI service (Fly.io).
//
// Used by the analyze edge function only. The token is the shared
// secret set both here (as `INTERNAL_API_TOKEN`) and on the AI service
// (`INTERNAL_API_TOKEN`).
//
// Failure modes are returned as structured ApiErrors:
//   - timeout / 5xx / network error → 502 upstream_error
//   - 4xx (other than 401) → 400-class error mapped through
//   - malformed body → 502 upstream_error

import { ApiError, Errors } from "./errors.ts";
import { log } from "./logger.ts";
import { requireEnv } from "./env.ts";

const DEFAULT_TIMEOUT_MS = Number.parseInt(
  Deno.env.get("AI_SERVICE_TIMEOUT_MS") ?? "30000",
  10,
);

export interface AiServicePet {
  pet_id: string;
  name: string;
  species: "dog" | "cat" | "rabbit" | "bird" | "reptile" | "other";
  breed?: string | null;
  age_years?: number | null;
  sex?: "male" | "female" | "unknown" | null;
  weight_kg?: number | null;
  conditions?: string[];
}

export interface AiServiceRequest {
  request_id: string;
  pet: AiServicePet;
  input_type: "photo" | "video" | "text";
  input_storage_url?: string | null;
  text_description?: string | null;
}

/**
 * The AI service's response payload. Field-by-field mirror of
 * `app.models.schemas.AnalysisResult` (Python side).
 */
export interface AiServiceResult {
  triage_level: "EMERGENCY" | "MONITOR" | "NORMAL";
  confidence: number;
  primary_concern: string;
  visible_symptoms: string[];
  differential: string[];
  recommended_actions: string[];
  urgency_timeframe: string;
  disclaimer_required: boolean;
  disclaimer_text: string;
  model_used: string;
  tier_used: number;
  emergency_override_applied: boolean;
  cross_verify_disagreement: boolean;
  ai_latency_ms: number;
  request_id: string;
}

export async function callAiService(
  body: AiServiceRequest,
): Promise<AiServiceResult> {
  const baseUrl = requireEnv("AI_SERVICE_URL");
  const token = requireEnv("INTERNAL_API_TOKEN");

  // Phase 1D: one retry on TRANSPORT errors only (connect refused, DNS
  // failure, ECONNRESET). HTTP responses — even 5xx — are NOT retried:
  // the AI service already retries within its own request lifecycle, and
  // retrying at the edge would double-bill provider tokens for a brief
  // outage. Quota is consumed once, before the call; a transport failure
  // means the request never reached the service, so retrying preserves
  // the quota → result contract.
  const maxAttempts = 2;
  let lastTransportErr: unknown;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), DEFAULT_TIMEOUT_MS);
    try {
      const resp = await fetch(`${baseUrl}/analyze`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-PawDoc-Internal-Token": token,
          "X-Request-ID": body.request_id,
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      if (!resp.ok) {
        log.error("ai_service_non_2xx", {
          status: resp.status,
          request_id: body.request_id,
          attempt,
        });
        throw Errors.upstream(`AI service returned HTTP ${resp.status}.`);
      }

      const parsed = (await resp.json()) as Record<string, unknown>;
      return validateAiServiceResult(parsed);
    } catch (err) {
      clearTimeout(timer);
      if (err instanceof ApiError) throw err;
      if (err instanceof DOMException && err.name === "AbortError") {
        log.error("ai_service_timeout", {
          request_id: body.request_id,
          attempt,
        });
        // Don't retry on timeout — the upstream is likely still processing
        // and a retry would just re-time-out.
        throw Errors.upstream("AI service timed out.");
      }
      lastTransportErr = err;
      log.warn("ai_service_transport_error", {
        request_id: body.request_id,
        attempt,
        error: (err as Error).message,
      });
      if (attempt < maxAttempts) {
        // brief backoff before retry
        await new Promise((r) => setTimeout(r, 250));
        continue;
      }
    } finally {
      clearTimeout(timer);
    }
  }
  log.error("ai_service_unreachable_after_retry", {
    request_id: body.request_id,
    error: (lastTransportErr as Error | undefined)?.message,
  });
  throw Errors.upstream("AI service unreachable.");
}

function validateAiServiceResult(raw: Record<string, unknown>): AiServiceResult {
  const requiredStrings = [
    "primary_concern",
    "urgency_timeframe",
    "disclaimer_text",
    "model_used",
    "request_id",
  ];
  for (const f of requiredStrings) {
    if (typeof raw[f] !== "string" || (raw[f] as string).length === 0) {
      throw Errors.upstream(`AI service response missing string field: ${f}`);
    }
  }
  const triage = raw.triage_level;
  if (triage !== "EMERGENCY" && triage !== "MONITOR" && triage !== "NORMAL") {
    throw Errors.upstream("AI service response missing triage_level.");
  }
  if (typeof raw.confidence !== "number") {
    throw Errors.upstream("AI service response missing confidence.");
  }
  if (typeof raw.tier_used !== "number") {
    throw Errors.upstream("AI service response missing tier_used.");
  }
  if (typeof raw.ai_latency_ms !== "number") {
    throw Errors.upstream("AI service response missing ai_latency_ms.");
  }

  return {
    triage_level: triage,
    confidence: raw.confidence as number,
    primary_concern: raw.primary_concern as string,
    visible_symptoms: (raw.visible_symptoms as string[] | undefined) ?? [],
    differential: (raw.differential as string[] | undefined) ?? [],
    recommended_actions: (raw.recommended_actions as string[] | undefined) ?? [],
    urgency_timeframe: raw.urgency_timeframe as string,
    disclaimer_required: Boolean(raw.disclaimer_required ?? true),
    disclaimer_text: raw.disclaimer_text as string,
    model_used: raw.model_used as string,
    tier_used: raw.tier_used as number,
    emergency_override_applied: Boolean(raw.emergency_override_applied ?? false),
    cross_verify_disagreement: Boolean(raw.cross_verify_disagreement ?? false),
    ai_latency_ms: raw.ai_latency_ms as number,
    request_id: raw.request_id as string,
  };
}
