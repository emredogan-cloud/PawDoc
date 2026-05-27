// Phase 3.3 — /claim-referral
// An authenticated user submits a referral code. We resolve + grant the reward
// through the transactional `claim_referral` RPC (service role), which enforces
// every fraud rule atomically (one claim per lifetime, no self-referral, race-
// safe). The client NEVER writes the referrals table or the reward columns —
// those are locked down to the service role (see 20260527030000_referrals.sql).
//
// Business outcomes return 200 with an { ok, status, message } body so the app
// can branch + fire analytics; only auth/transport failures use 401/503.
import { createClient } from "jsr:@supabase/supabase-js@2";
// deno-lint-ignore no-import-assertions
import { referralResult } from "../_shared/referral.mjs";

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

  // Resolve the caller from their JWT (RLS-scoped client).
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: auth } = await userClient.auth.getUser();
  const user = auth?.user;
  if (!user) return json({ ok: false, status: "unauthorized", message: "Please sign in." }, 401);

  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, status: "error", message: "Invalid request." }, 400);
  }
  const code = typeof body?.code === "string" ? body.code.trim() : "";
  if (!code) return json(referralResult("invalid_code"));

  // The claimer_id is the JWT-derived user — never taken from the body — so a
  // caller can only ever claim on their OWN behalf.
  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
  let status = "error";
  try {
    const { data, error } = await admin.rpc("claim_referral", {
      claimer_id: user.id,
      code,
    });
    if (error) throw error;
    status = (data as string) ?? "error";
  } catch (_err) {
    return json(
      { ok: false, status: "error", message: "Couldn't process the referral. Please try again." },
      503,
    );
  }

  return json(referralResult(status));
});
