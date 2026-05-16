// =============================================================================
// /revenuecat-webhook — subscription state sync from RevenueCat.
// =============================================================================
// RevenueCat posts subscription lifecycle events here (INITIAL_PURCHASE,
// RENEWAL, CANCELLATION, EXPIRATION, BILLING_ISSUE, etc.). The handler maps
// the event_type to a `users.subscription_status` value and updates the
// matching public.users row by `revenuecat_user_id`.
//
// Authentication: shared bearer token configured in RevenueCat Dashboard.
// Set REVENUECAT_WEBHOOK_AUTH_TOKEN in edge function env.
//
// Phase 1D — fully implemented. The mapping rules live in state_map.ts so
// they can be unit-tested in isolation.
// =============================================================================

import { preflight, resolveOrigin } from "../_shared/cors.ts";
import { Errors, withErrorHandler } from "../_shared/errors.ts";
import { log } from "../_shared/logger.ts";
import { verifyWebhookSecret } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabase-admin.ts";
import { asObject, asString, readJson } from "../_shared/validation.ts";
import { deriveUpdate, IncomingEvent } from "./state_map.ts";

interface RevenueCatEvent {
  readonly type: string;
  readonly appUserId: string;
  readonly productId: string | null;
  readonly environment?: string;
}

function parseRevenueCatEvent(body: unknown): RevenueCatEvent {
  const obj = asObject(body);
  const event = asObject(obj.event, "event");
  return {
    type: asString(event.type, "event.type"),
    appUserId: asString(event.app_user_id, "event.app_user_id"),
    productId: typeof event.product_id === "string" ? event.product_id : null,
    environment: typeof event.environment === "string" ? event.environment : undefined,
  };
}

async function applyUpdate(
  appUserId: string,
  update: { status: "free" | "trial" | "premium" | "family"; tier: string },
): Promise<{ matched: number }> {
  // RevenueCat's `app_user_id` is the value we set when calling
  // `Purchases.logIn(userId)` on the mobile — i.e., the Supabase user id.
  const admin = supabaseAdmin();
  const updateRow: Record<string, unknown> = {
    subscription_status: update.status,
    subscription_tier: update.tier === "" ? null : update.tier,
    revenuecat_user_id: appUserId,
  };
  const { data, error } = await admin
    .from("users")
    .update(updateRow)
    .eq("id", appUserId)
    .select("id");

  if (error) {
    log.error("revenuecat_db_update_failed", {
      fn: "revenuecat-webhook",
      code: error.code,
      app_user_id: appUserId,
    });
    throw Errors.upstream("Failed to persist subscription state.");
  }
  return { matched: data?.length ?? 0 };
}

const handler = withErrorHandler(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return preflight(req.headers.get("Origin"));
  }
  if (req.method !== "POST") {
    throw Errors.validation("Method not allowed.");
  }

  verifyWebhookSecret(req, "REVENUECAT_WEBHOOK_AUTH_TOKEN");
  const body = await readJson(req);
  const event = parseRevenueCatEvent(body);

  log.info("revenuecat_event_received", {
    fn: "revenuecat-webhook",
    type: event.type,
    app_user_id: event.appUserId,
    product_id: event.productId,
    environment: event.environment,
  });

  const incoming: IncomingEvent = {
    type: event.type,
    productId: event.productId,
  };
  const decision = deriveUpdate(incoming);

  let applied = false;
  let matched = 0;
  if (decision.status !== null) {
    const result = await applyUpdate(event.appUserId, decision);
    matched = result.matched;
    applied = matched > 0;
    log.info("revenuecat_state_applied", {
      fn: "revenuecat-webhook",
      app_user_id: event.appUserId,
      new_status: decision.status,
      new_tier: decision.tier,
      matched_rows: matched,
    });
    if (matched === 0) {
      log.warn("revenuecat_no_matching_user", {
        fn: "revenuecat-webhook",
        app_user_id: event.appUserId,
        type: event.type,
      });
    }
  } else {
    log.info("revenuecat_event_acknowledged", {
      fn: "revenuecat-webhook",
      type: event.type,
      reason: decision.reason,
    });
  }

  const origin = resolveOrigin(req.headers.get("Origin")) ?? "*";
  return new Response(
    JSON.stringify({
      ok: true,
      applied,
      matched_rows: matched,
    }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": origin,
        "Vary": "Origin",
      },
    },
  );
});

Deno.serve((req: Request) => Promise.resolve(handler(req)));
