// Phase 1.4 — /revenuecat-webhook
// Updates users.subscription_status when a RevenueCat entitlement changes.
// CR #21: verifies the shared Authorization secret before trusting the event —
// an unsigned/forged webhook must not be able to grant "premium".
// verify_jwt is disabled (RevenueCat calls it without a user JWT).
import { createClient } from "jsr:@supabase/supabase-js@2";
// deno-lint-ignore no-import-assertions
import { addonCreditsFromEvent, entitlementStatusFromEvent } from "../_shared/revenuecat.mjs";
// deno-lint-ignore no-import-assertions
import { timingSafeEqual } from "../_shared/timing_safe_equal.mjs";

Deno.serve(async (req: Request) => {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

  // CR #21 / GAP-E5 — verify the secret RevenueCat sends in the Authorization
  // header with a constant-time compare. A plain `!==` short-circuits at the
  // first differing byte, leaking the secret via response timing. Accept the
  // bare secret or a "Bearer <secret>" form.
  const expected = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  const auth = req.headers.get("Authorization") ?? "";
  const authorized = !!expected &&
    (timingSafeEqual(auth, expected) || timingSafeEqual(auth, `Bearer ${expected}`));
  if (!authorized) {
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

  // GAP-E5 — idempotency. Claim this event id BEFORE applying any credit so a
  // retried or duplicated delivery can't grant it twice. The primary-key insert
  // is the atomic guard: a duplicate hits unique_violation (23505) and is
  // skipped as already-processed. RevenueCat always sends event.id; if it were
  // somehow absent we fall through unguarded rather than reject (subscription
  // status writes are idempotent by nature — only the add-on credit is at risk).
  const eventId = event?.id != null ? String(event.id) : null;
  if (eventId) {
    const { error: claimErr } = await admin
      .from("processed_rc_events")
      .insert({ event_id: eventId, app_user_id: appUserId, event_type: event?.type ?? null });
    if (claimErr) {
      if (claimErr.code === "23505") {
        return json({ ok: true, changed: false, idempotent: true });
      }
      console.error("revenuecat-webhook claim failed", claimErr.message);
      return json({ error: "claim failed" }, 500);
    }
  }

  // Release the idempotency claim so a RevenueCat retry can re-process after a
  // transient failure below — otherwise the credit would be lost permanently.
  const releaseClaim = async () => {
    if (eventId) {
      await admin.from("processed_rc_events").delete().eq("event_id", eventId);
    }
  };

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
      await releaseClaim();
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
      await releaseClaim();
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
    await releaseClaim();
    return json({ error: "update failed" }, 500);
  }
  return json({ ok: true, changed: true, status });
});
