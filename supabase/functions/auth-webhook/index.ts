// Phase 1.1 — /auth-webhook
// Creates the public.users row when a new auth user signs up.
//
// Security (Critical Review #21): the request signature is verified with the
// shared hook secret BEFORE any work, so a forged POST cannot provision rows.
// Uses the standardwebhooks scheme that Supabase Auth "Send" hooks sign with.
//
// Configure this as a Supabase Auth Hook (see docs/runbooks/13). It is invoked
// without a user JWT, so verify_jwt is disabled for it in config.toml.
//
// Surfaced (NOT auto-added): a Postgres `on auth.users` trigger is a strictly
// more robust way to guarantee the profile row (no network, unforgeable). The
// roadmap specifies this Edge Function, so that is what ships; consider the
// trigger as a belt-and-braces follow-up.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

Deno.serve(async (req) => {
  const hookSecret = Deno.env.get("SUPABASE_AUTH_WEBHOOK_SECRET");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!hookSecret || !supabaseUrl || !serviceRoleKey) {
    return new Response("server misconfigured", { status: 500 });
  }

  const payload = await req.text();
  const headers = Object.fromEntries(req.headers);

  // Verify the signature (throws on tamper / replay). Supabase secrets are
  // prefixed `v1,whsec_`; standardwebhooks wants the bare base64 portion.
  let event: Record<string, unknown>;
  try {
    const wh = new Webhook(hookSecret.replace("v1,whsec_", ""));
    event = wh.verify(payload, headers) as Record<string, unknown>;
  } catch (_err) {
    return new Response("invalid signature", { status: 401 });
  }

  // Tolerate the different hook payload shapes ({ user }, { record }, or flat).
  const record = (event.user ?? event.record ?? event) as Record<string, unknown>;
  const id = record?.id as string | undefined;
  const email = (record?.email as string | null) ?? null;
  if (!id) return new Response("no user id in payload", { status: 400 });

  // service_role bypasses RLS — the only correct way to provision the row here.
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { error } = await admin
    .from("users")
    .upsert({ id, email }, { onConflict: "id", ignoreDuplicates: true });

  if (error) {
    console.error("auth-webhook upsert failed", { id, message: error.message });
    return new Response("could not provision user", { status: 500 });
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "content-type": "application/json" },
  });
});
