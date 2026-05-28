// Phase 1.4 — /revenuecat-webhook
// Updates users.subscription_status when a RevenueCat entitlement changes.
// CR #21: verifies the shared Authorization secret before trusting the event —
// an unsigned/forged webhook must not be able to grant "premium".
// verify_jwt is disabled (RevenueCat calls it without a user JWT).
import { createClient } from "jsr:@supabase/supabase-js@2";
// deno-lint-ignore no-import-assertions
import { addonCreditsFromEvent, entitlementStatusFromEvent } from "../_shared/revenuecat.mjs";

Deno.serve(async (req: Request) => {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

  // CR #21 — verify the secret RevenueCat sends in the Authorization header.
  const expected = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  const auth = req.headers.get("Authorization") ?? "";
  if (!expected || (auth !== expected && auth !== `Bearer ${expected}`)) {
    return json({ error: "unauthorized" }, 401);
  }

  // deno-lint-ignore no-explicit-any
  let payload: any;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid JSON" }, 400);
  }

  const event = payload?.event ?? payload;
  const appUserId = event?.app_user_id;
  if (!appUserId) return json({ error: "no app_user_id" }, 400);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // Phase 6.3 — one-time add-on credits (e.g. the $4.99 PDF report). Applied
  // FIRST so a consumable purchase is recorded even when there's no
  // subscription status change.
  const addon = addonCreditsFromEvent(event);
  if (addon) {
    // Atomic increment: read-modify-write via RPC would be cleaner; for now
    // we fetch + increment + update inside one webhook handler, which is
    // single-flighted per event by RevenueCat's retry behavior.
    const { data: profile, error: readErr } = await admin
      .from("users")
      .select(addon.column)
      .eq("id", appUserId).single();
    if (readErr) {
      console.error("revenuecat-webhook addon read failed", readErr.message);
      return json({ error: "addon read failed" }, 500);
    }
    // deno-lint-ignore no-explicit-any
    const current = (profile as any)?.[addon.column] ?? 0;
    const { error: writeErr } = await admin
      .from("users")
      .update({
        [addon.column]: current + addon.delta,
        revenuecat_user_id: appUserId,
      })
      .eq("id", appUserId);
    if (writeErr) {
      console.error("revenuecat-webhook addon update failed", writeErr.message);
      return json({ error: "addon update failed" }, 500);
    }
    return json({
      ok: true,
      changed: true,
      addon: { product_id: addon.productId, column: addon.column, delta: addon.delta },
    });
  }

  // Subscription tier mapping (premium / family / trial / b2b_lite / free).
  const status = entitlementStatusFromEvent(event);
  if (!status) return json({ ok: true, changed: false }); // e.g. CANCELLATION: no change

  // The app sets RevenueCat appUserID = the Supabase user id (Purchases.logIn).
  const { error } = await admin
    .from("users")
    .update({ subscription_status: status, revenuecat_user_id: appUserId })
    .eq("id", appUserId);
  if (error) {
    console.error("revenuecat-webhook update failed", error.message);
    return json({ error: "update failed" }, 500);
  }
  return json({ ok: true, changed: true, status });
});
