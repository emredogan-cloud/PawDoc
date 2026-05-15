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
// Phase 1A: validates signature + payload shape, logs the event, returns
// 200. Phase 1B implements the actual state mapping. The acked-but-not-
// applied behaviour is safe: RevenueCat will retry; once 1B ships we'll
// replay any missed events from the dashboard if needed.
// =============================================================================

import { preflight, resolveOrigin } from "../_shared/cors.ts";
import { Errors, withErrorHandler } from "../_shared/errors.ts";
import { log } from "../_shared/logger.ts";
import { verifyWebhookSecret } from "../_shared/auth.ts";
import { asObject, asString, readJson } from "../_shared/validation.ts";

interface RevenueCatEvent {
  readonly type: string;
  readonly appUserId: string;
  readonly productId?: string;
  readonly environment?: string;
}

function parseRevenueCatEvent(body: unknown): RevenueCatEvent {
  const obj = asObject(body);
  const event = asObject(obj.event, "event");
  return {
    type: asString(event.type, "event.type"),
    appUserId: asString(event.app_user_id, "event.app_user_id"),
    productId: typeof event.product_id === "string" ? event.product_id : undefined,
    environment: typeof event.environment === "string" ? event.environment : undefined,
  };
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

  // Phase 1B: switch on event.type → set subscription_status accordingly.
  //   - INITIAL_PURCHASE, RENEWAL, PRODUCT_CHANGE → 'premium' | 'family'
  //   - CANCELLATION, EXPIRATION, BILLING_ISSUE   → 'free'
  //   - NON_RENEWING_PURCHASE                      → no change

  const origin = resolveOrigin(req.headers.get("Origin")) ?? "*";
  return new Response(JSON.stringify({ ok: true, applied: false }), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": origin,
      "Vary": "Origin",
    },
  });
});

Deno.serve((req: Request) => Promise.resolve(handler(req)));
