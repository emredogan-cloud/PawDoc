// Phase 6.3.1 — /invite-family-member (verify_jwt = true).
//
// Issues a 48-hour pending invite for the caller's family group. The caller
// MUST be on the family or b2b_lite tier (server-enforced — the client UI
// also gates but it can't be the only check). If RESEND_API_KEY is set we
// email the link via Resend; otherwise we log the magic link to the function
// logs and still return it in the JSON body for local testing / fallback
// "copy link" UX.

import { createClient } from "jsr:@supabase/supabase-js@2";
// deno-lint-ignore no-import-assertions
import {
  INVITE_ELIGIBLE_TIERS,
  buildInviteEmail,
  generateInviteToken,
  inviteLink,
  normalizeEmail,
} from "../_shared/invites.mjs";

Deno.serve(async (req: Request) => {
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", "x-request-id": requestId },
    });

  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: auth } = await userClient.auth.getUser();
  const user = auth?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }
  const email = normalizeEmail(body?.email);
  if (!email) return json({ error: "valid email is required" }, 400);

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

  // Tier check (server-side). Free/Premium are excluded by design — Family
  // unlocks sharing.
  const { data: profile, error: profileErr } = await admin
    .from("users")
    .select("subscription_status, email")
    .eq("id", user.id)
    .single();
  if (profileErr) {
    console.error("invite-family-member: profile read failed", requestId, profileErr.message);
    return json({ error: "profile lookup failed" }, 500);
  }
  if (!INVITE_ELIGIBLE_TIERS.has(profile?.subscription_status ?? "free")) {
    return json({
      error: "tier_not_eligible",
      message: "Family Sharing is part of the Family and Sitter plans. Upgrade to invite a member.",
    }, 402);
  }

  // Resolve the inviter's owned family group. By construction (Phase 6.3
  // trigger) every user owns at least their solo group; we pick the OLDEST
  // owned group, which is the solo group → on first invite we promote it.
  const { data: owned, error: groupErr } = await admin
    .from("family_groups")
    .select("id, name")
    .eq("owner_user_id", user.id)
    .order("created_at", { ascending: true })
    .limit(1);
  if (groupErr || !owned || owned.length === 0) {
    console.error("invite-family-member: no owned group", requestId, groupErr?.message);
    return json({ error: "no owned family group" }, 500);
  }
  const groupId = owned[0].id;
  const groupName = owned[0].name as string;

  // Cheap abuse cap — at most 10 outstanding invites per group.
  const { count } = await admin
    .from("family_invites")
    .select("id", { count: "exact", head: true })
    .eq("group_id", groupId)
    .eq("status", "pending");
  if ((count ?? 0) >= 10) {
    return json({ error: "too_many_pending_invites" }, 429);
  }

  const token = generateInviteToken();
  const { error: insertErr } = await admin.from("family_invites").insert({
    group_id: groupId,
    invited_by_user_id: user.id,
    invited_email: email,
    token,
  });
  if (insertErr) {
    console.error("invite-family-member: insert failed", requestId, insertErr.message);
    return json({ error: "could not create invite" }, 500);
  }

  const linkBase = Deno.env.get("INVITE_LINK_BASE_URL") || "https://pawdoc.app/invite";
  const link = inviteLink(linkBase, token);

  // Best-effort email via Resend; never fail the request on a send error —
  // the client can fall back to a "copy link" UX with the link in the
  // response body.
  const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
  const resendFrom = Deno.env.get("RESEND_FROM") ?? "PawDoc <noreply@pawdoc.app>";
  let emailSent = false;
  if (resendKey) {
    try {
      const payload = buildInviteEmail({
        to: email,
        link,
        inviterName: profile?.email ?? "A PawDoc user",
        groupName,
      });
      const resp = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "authorization": `Bearer ${resendKey}`,
        },
        body: JSON.stringify({
          from: resendFrom,
          to: [payload.to],
          subject: payload.subject,
          text: payload.text,
        }),
      });
      emailSent = resp.ok;
      if (!resp.ok) console.error("invite-family-member: resend non-ok", requestId, resp.status);
    } catch (err) {
      console.error("invite-family-member: resend threw", requestId, String(err));
    }
  } else {
    console.info("invite-family-member: no RESEND_API_KEY — magic link:", link);
  }

  return json({
    ok: true,
    invite_link: link,
    expires_in_hours: 48,
    email_sent: emailSent,
  });
});
