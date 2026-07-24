// Phase 2.1 — /delete-account (CR #9, Apple Guideline 5.1.1(v))
// Deletes the CALLING user's account. The user is taken from the verified JWT
// (never a body param), so a caller can only delete themselves. Deleting the
// auth user cascades to public.users and onward to pets/analyses/reminders/
// children via the ON DELETE CASCADE FKs from Phase 1.1 (CR #20).
//
// GAP-A6: the DB cascade alone left the user's R2 media (uploads/<uid>/*) and
// their third-party subjects (RevenueCat / PostHog) behind — a real
// erasure gap (GDPR/KVKK + Apple 5.1.1(v); pet photos can contain people/homes).
// We now purge those FIRST, log compliance evidence (uid hash only), then delete
// the auth user. verify_jwt stays default (true).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.20";
// deno-lint-ignore no-import-assertions
import { keysUnderPrefix, parseListKeys, parseNextToken } from "../_shared/r2.mjs";

async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Delete every R2 object under the user's namespaces (paginated). Returns the
// count. Next Evolution Phase 2 widened this from uploads/ alone to every media
// scope (uploads = analysis inputs, memories = pet journal, chat = assistant
// attachments) so erasure stays complete as surfaces grow.
// No-op (0) if R2 isn't configured, so the deletion still completes.
const USER_MEDIA_PREFIXES = ["uploads", "memories", "chat"];

async function purgeUserUploads(uid: string): Promise<number> {
  const accountId = Deno.env.get("R2_ACCOUNT_ID");
  const bucket = Deno.env.get("R2_BUCKET");
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
  if (!accountId || !bucket || !accessKeyId || !secretAccessKey) return 0;
  const r2 = new AwsClient({ accessKeyId, secretAccessKey, service: "s3", region: "auto" });
  const base = `https://${accountId}.r2.cloudflarestorage.com/${bucket}`;
  let deleted = 0;
  for (const scope of USER_MEDIA_PREFIXES) {
    const prefix = `${scope}/${uid}/`;
    let token: string | null = null;
    do {
      const u = new URL(base);
      u.searchParams.set("list-type", "2");
      u.searchParams.set("prefix", prefix);
      if (token) u.searchParams.set("continuation-token", token);
      const resp = await r2.fetch(u.toString(), { method: "GET" });
      if (!resp.ok) break;
      const xml = await resp.text();
      // keysUnderPrefix is the safety net — never delete outside the uid prefix.
      for (const key of keysUnderPrefix(parseListKeys(xml), prefix)) {
        const d = await r2.fetch(`${base}/${key}`, { method: "DELETE" });
        if (d.ok || d.status === 404) deleted++;
      }
      token = parseNextToken(xml);
    } while (token);
  }
  return deleted;
}

// Best-effort deletion of third-party subjects. Each is independent, non-fatal,
// and skipped when its credential isn't configured (so deletion never blocks).
async function deleteThirdParties(uid: string): Promise<Record<string, string>> {
  const out: Record<string, string> = {};
  // Canonical slot name is REVENUECAT_API_KEY (ENVIRONMENT_VARS.md + Doppler
  // prd). The old REVENUECAT_SECRET_API_KEY drift meant the RevenueCat purge
  // silently no-op'd on account deletion (guarded, so no crash) — a GDPR
  // completeness gap. Accept the legacy name as a fallback for safety.
  const rcKey = Deno.env.get("REVENUECAT_API_KEY") ??
      Deno.env.get("REVENUECAT_SECRET_API_KEY");
  if (rcKey) {
    try {
      const r = await fetch(`https://api.revenuecat.com/v1/subscribers/${uid}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${rcKey}` },
      });
      out.revenuecat = String(r.status);
    } catch (e) {
      out.revenuecat = `error:${e}`;
    }
  }
  const phKey = Deno.env.get("POSTHOG_PERSONAL_API_KEY");
  const phProj = Deno.env.get("POSTHOG_PROJECT_ID");
  const phHost = Deno.env.get("POSTHOG_HOST") ?? "https://us.posthog.com";
  if (phKey && phProj) {
    try {
      const r = await fetch(
        `${phHost}/api/projects/${phProj}/persons/?distinct_id=${encodeURIComponent(uid)}`,
        { method: "DELETE", headers: { Authorization: `Bearer ${phKey}` } },
      );
      out.posthog = String(r.status);
    } catch (e) {
      out.posthog = `error:${e}`;
    }
  }
  return out;
}

Deno.serve(async (req: Request) => {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
      auth: { persistSession: false },
    },
  );
  const { data: auth } = await userClient.auth.getUser();
  const user = auth?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // GAP-A6: erase media + third-party PII BEFORE the auth delete. Each step is
  // non-fatal — a third-party hiccup must not strand the user's auth deletion.
  let r2Deleted = 0;
  let thirdParty: Record<string, string> = {};
  try {
    r2Deleted = await purgeUserUploads(user.id);
  } catch (e) {
    console.error("delete-account: R2 purge failed", e);
  }
  try {
    thirdParty = await deleteThirdParties(user.id);
  } catch (e) {
    console.error("delete-account: third-party purge failed", e);
  }
  // Compliance evidence — only a hash of the uid + counts (no PII).
  try {
    await admin.from("deletion_log").insert({
      uid_hash: await sha256Hex(user.id),
      r2_objects_deleted: r2Deleted,
      third_party: thirdParty,
    });
  } catch (e) {
    console.error("delete-account: deletion_log insert failed", e);
  }

  // Removes the auth user; FK cascades wipe all of their app data.
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    console.error("delete-account failed", error.message);
    return json({ error: "deletion failed" }, 500);
  }
  return json({ ok: true, r2_objects_deleted: r2Deleted });
});
