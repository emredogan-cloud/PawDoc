// Phase 3.3 (Part 2) — /process-reminders
// Cron-driven (pg_cron + pg_net, hourly). Sends due health reminders and a
// gentle inactivity "we miss you" nudge via the OneSignal REST API.
//
// SECURITY: this is NOT user-facing. pg_net calls it with an `x-cron-secret`
// header that must equal the CRON_SECRET env (Doppler). The check fails CLOSED
// (no secret configured -> 401), so a malicious actor cannot trigger a public
// notification blast. verify_jwt is disabled for it (config.toml).
//
// The row selection + the no-spam cooldown live in DB functions (due_reminders,
// users_to_reengage), both locked to the service role.
import { createClient } from "jsr:@supabase/supabase-js@2";
// deno-lint-ignore no-import-assertions
import {
  cronSecretValid,
  oneSignalBody,
  reengagementNotification,
  reminderNotification,
} from "../_shared/reminders.mjs";

const ONESIGNAL_API = "https://onesignal.com/api/v1/notifications";

// deno-lint-ignore no-explicit-any
async function sendOneSignal(appId: string, restKey: string, notification: any): Promise<boolean> {
  if (!appId || !restKey) return false; // not configured -> no-op (don't crash the cron)
  try {
    const resp = await fetch(ONESIGNAL_API, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Basic ${restKey}` },
      body: JSON.stringify(oneSignalBody(appId, notification)),
    });
    return resp.ok;
  } catch (_err) {
    return false;
  }
}

Deno.serve(async (req: Request) => {
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "x-request-id": requestId },
    });

  // Secret-header auth (fail closed).
  if (!cronSecretValid(req.headers.get("x-cron-secret"), Deno.env.get("CRON_SECRET") ?? "")) {
    return json({ error: "forbidden" }, 401);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const appId = Deno.env.get("ONESIGNAL_APP_ID") ?? "";
  const restKey = Deno.env.get("ONESIGNAL_REST_API_KEY") ?? "";

  let remindersSent = 0;
  let reengagementSent = 0;

  // 1. Due reminders -> push -> mark sent (so they never fire twice).
  const { data: due, error: dueErr } = await admin.rpc("due_reminders");
  if (dueErr) console.error("process-reminders: due_reminders failed", requestId, dueErr.message);
  if (Array.isArray(due)) {
    for (const r of due) {
      if (await sendOneSignal(appId, restKey, reminderNotification(r))) {
        await admin.from("reminders")
          .update({ is_sent: true, notification_sent_at: new Date().toISOString() })
          .eq("id", r.id);
        remindersSent++;
      }
    }
  }

  // 2. Inactivity re-engagement -> push -> stamp last_reengagement_sent_at.
  // The cooldown is enforced both in the query (users_to_reengage) AND by this
  // stamp, so a user gets at most one nudge per 30-day window (no-spam rule).
  const { data: lapsed, error: lapsedErr } =
    await admin.rpc("users_to_reengage", { inactivity_days: 30, cooldown_days: 30 });
  if (lapsedErr) console.error("process-reminders: users_to_reengage failed", requestId, lapsedErr.message);
  if (Array.isArray(lapsed)) {
    for (const u of lapsed) {
      if (await sendOneSignal(appId, restKey, reengagementNotification(u.player_id))) {
        await admin.from("users")
          .update({ last_reengagement_sent_at: new Date().toISOString() })
          .eq("id", u.user_id);
        reengagementSent++;
      }
    }
  }

  return json({
    ok: true,
    reminders_sent: remindersSent,
    reengagement_sent: reengagementSent,
    request_id: requestId,
  });
});
