// =============================================================================
// /auth-webhook — Supabase Auth event handler.
// =============================================================================
// Supabase Auth sends server-side events to this endpoint when users sign up,
// sign in, get deleted, etc. We use it to mirror `auth.users` into the
// `public.users` table that all our RLS policies key on.
//
// Authentication: shared bearer token. Configure under
// Supabase Dashboard → Authentication → Hooks → Send HTTP Hook.
// The hook's bearer token MUST match SUPABASE_AUTH_WEBHOOK_SECRET in the
// edge function's env.
//
// Idempotency: we use INSERT ... ON CONFLICT DO NOTHING so a replay of
// `user.created` is a no-op rather than an error.
// =============================================================================

import { preflight, resolveOrigin } from "../_shared/cors.ts";
import { Errors, withErrorHandler } from "../_shared/errors.ts";
import { log, maskEmail } from "../_shared/logger.ts";
import { verifyWebhookSecret } from "../_shared/auth.ts";
import { supabaseAdmin } from "../_shared/supabase-admin.ts";
import { asObject, asOneOf, asString, asUuid, readJson } from "../_shared/validation.ts";

const EVENT_TYPES = [
  "INSERT",
  "UPDATE",
  "DELETE",
  "user.created",
  "user.deleted",
] as const;
type EventType = (typeof EVENT_TYPES)[number];

interface AuthEvent {
  type: EventType;
  record: {
    id: string;
    email: string | null;
  };
}

function parseAuthEvent(body: unknown): AuthEvent {
  const obj = asObject(body);
  // Supabase Auth hook payloads have varied — both top-level `type` (DB
  // webhook style) and `event` (Send-Email-Hook style) appear in the wild.
  // Accept either.
  const rawType = (obj.type ?? obj.event) as unknown;
  const type = asOneOf(rawType, EVENT_TYPES, "type");

  // The user row is either at `record` (DB webhook) or `user_payload.user`
  // (Send-Email hook). Phase 1A only wires the DB-webhook form; we'll
  // extend in 1B if needed.
  const record = asObject(obj.record, "record");
  const id = asUuid(record.id, "record.id");
  const email = record.email === null ? null : asString(record.email, "record.email");

  return { type, record: { id, email } };
}

async function handleUserCreated(event: AuthEvent): Promise<void> {
  const { id, email } = event.record;
  // Idempotent insert. We don't UPSERT email here — the SQL UNIQUE constraint
  // would surface a conflict the same way for ON CONFLICT DO NOTHING.
  const { error } = await supabaseAdmin()
    .from("users")
    .insert({ id, email })
    .select("id")
    .maybeSingle();

  if (error && error.code !== "23505") {
    // 23505 = unique_violation; treat as idempotent success.
    log.error("auth_webhook_insert_failed", { code: error.code });
    throw Errors.upstream("Failed to persist user.");
  }
  log.info("user_provisioned", {
    fn: "auth-webhook",
    user_id: id,
    email: email ? maskEmail(email) : null,
  });
}

const handler = withErrorHandler(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return preflight(req.headers.get("Origin"));
  }
  if (req.method !== "POST") {
    throw Errors.validation("Method not allowed.");
  }

  verifyWebhookSecret(req, "SUPABASE_AUTH_WEBHOOK_SECRET");
  const body = await readJson(req);
  const event = parseAuthEvent(body);

  // Phase 1A: only handle the create path. Other events are acked but ignored.
  switch (event.type) {
    case "INSERT":
    case "user.created":
      await handleUserCreated(event);
      break;
    case "UPDATE":
      log.info("auth_event_ignored_phase1a", {
        fn: "auth-webhook",
        type: event.type,
      });
      break;
    case "DELETE":
    case "user.deleted":
      // public.users.id FKs auth.users.id ON DELETE CASCADE, so deletion is
      // handled at the DB layer. We just log here for audit.
      log.info("user_delete_observed", {
        fn: "auth-webhook",
        user_id: event.record.id,
      });
      break;
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(req),
    },
  });
});

function corsHeaders(req: Request): Record<string, string> {
  const origin = resolveOrigin(req.headers.get("Origin")) ?? "*";
  return {
    "Access-Control-Allow-Origin": origin,
    "Vary": "Origin",
  };
}

Deno.serve((req: Request) => Promise.resolve(handler(req)));
