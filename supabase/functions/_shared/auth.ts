// Authentication helpers for edge functions.
//
// Two flavours:
//   - `requireUser(req)` — validates an inbound user JWT and returns the
//     user's id. Use in any function called by the mobile app.
//   - `verifyWebhookSecret(req, envVar)` — constant-time compares an
//     Authorization-bearer secret against a server env. Use for inbound
//     webhooks (Supabase Auth hooks, RevenueCat).

import { Errors } from "./errors.ts";
import { supabaseAdmin } from "./supabase-admin.ts";
import { log } from "./logger.ts";

export interface AuthenticatedUser {
  readonly id: string;
  readonly jwt: string;
}

function extractBearer(req: Request): string {
  const header = req.headers.get("Authorization") ?? "";
  if (!header.startsWith("Bearer ")) {
    throw Errors.unauthorized("Missing or malformed Authorization header.");
  }
  const token = header.slice("Bearer ".length).trim();
  if (token.length === 0) {
    throw Errors.unauthorized("Empty bearer token.");
  }
  return token;
}

/**
 * Resolve the caller to a Supabase Auth user.
 *
 * Throws `Errors.unauthorized` if the token is missing, malformed, or
 * not validated by Supabase Auth.
 */
export async function requireUser(req: Request): Promise<AuthenticatedUser> {
  const jwt = extractBearer(req);
  const { data, error } = await supabaseAdmin().auth.getUser(jwt);
  if (error || !data.user) {
    log.warn("auth_token_rejected", { reason: error?.message ?? "no_user" });
    throw Errors.unauthorized("Invalid or expired token.");
  }
  return { id: data.user.id, jwt };
}

/**
 * Verify a webhook-style shared secret in the Authorization header.
 * Uses a constant-time comparison to avoid timing oracles.
 */
export function verifyWebhookSecret(req: Request, envVar: string): void {
  const expected = Deno.env.get(envVar);
  if (!expected) {
    // Misconfiguration; fail closed.
    log.error("webhook_secret_unconfigured", { envVar });
    throw Errors.unauthorized("Webhook not configured.");
  }
  const provided = extractBearer(req);
  if (!constantTimeEquals(provided, expected)) {
    log.warn("webhook_secret_mismatch", { envVar });
    throw Errors.unauthorized("Invalid webhook signature.");
  }
}

function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}
