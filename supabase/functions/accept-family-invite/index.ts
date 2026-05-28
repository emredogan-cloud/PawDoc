// Phase 6.3.1 — /accept-family-invite (verify_jwt = true).
//
// Validates a pending invite token and adds the caller as a member of the
// inviter's family group. Rejects with `already_in_family` if the caller is
// in any shared group beyond their solo one (MVP simplification — group
// merging is a follow-up). Idempotent: a second call with the same token
// after acceptance returns the same group_id, so a double-tap on the deep
// link is safe.

import { createClient } from "jsr:@supabase/supabase-js@2";

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
  const token = body?.token;
  if (!token || typeof token !== "string") {
    return json({ error: "token required" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });

  // Look up the invite — service role so the rest of the validation is
  // straightforward.
  const { data: invite, error: inviteErr } = await admin
    .from("family_invites")
    .select("id, group_id, invited_by_user_id, status, expires_at, accepted_by_user_id")
    .eq("token", token)
    .single();
  if (inviteErr || !invite) return json({ error: "invite_not_found" }, 404);

  // Idempotency — if the caller already accepted this invite, return the
  // group they joined. Anyone ELSE trying to reuse the token is rejected.
  if (invite.status === "accepted") {
    if (invite.accepted_by_user_id === user.id) {
      const { data: group } = await admin
        .from("family_groups").select("id, name").eq("id", invite.group_id).single();
      return json({ ok: true, already_accepted: true, group_id: invite.group_id, group_name: group?.name ?? null });
    }
    return json({ error: "invite_already_used" }, 409);
  }
  if (invite.status !== "pending") return json({ error: "invite_not_pending" }, 410);
  if (new Date(invite.expires_at) <= new Date()) {
    // Best-effort mark expired so it stops showing up in dashboards.
    await admin.from("family_invites").update({ status: "expired" }).eq("id", invite.id);
    return json({ error: "invite_expired" }, 410);
  }

  // MVP rule (per the task brief): block users who are already in any shared
  // family beyond their solo group. The helper count_shared_group_memberships
  // is SECURITY DEFINER so it sees the full picture.
  const { data: sharedCountRows, error: helperErr } = await admin.rpc(
    "count_shared_group_memberships",
    { check_user_id: user.id },
  );
  if (helperErr) {
    console.error("accept-family-invite: helper failed", requestId, helperErr.message);
    return json({ error: "validation failed" }, 500);
  }
  const sharedCount = typeof sharedCountRows === "number" ? sharedCountRows : 0;
  if (sharedCount > 0) {
    return json({
      error: "already_in_family",
      message: "You're already in a family group. Leave it before joining another.",
    }, 409);
  }

  // Don't let a user re-invite themselves accidentally.
  if (invite.invited_by_user_id === user.id) {
    return json({ error: "cannot_invite_self" }, 400);
  }

  // Add the member + mark the invite accepted in two writes. Both are by the
  // service role, which the family_members RLS otherwise would have blocked
  // (the inserting user isn't a group owner).
  const { error: memberErr } = await admin
    .from("family_members")
    .insert({ group_id: invite.group_id, user_id: user.id, role: "member" });
  if (memberErr) {
    // 23505 unique_violation = the user is already a member (race).
    if (memberErr.code !== "23505") {
      console.error("accept-family-invite: member insert failed", requestId, memberErr.message);
      return json({ error: "could not join family" }, 500);
    }
  }
  await admin
    .from("family_invites")
    .update({
      status: "accepted",
      accepted_by_user_id: user.id,
      accepted_at: new Date().toISOString(),
    })
    .eq("id", invite.id);

  const { data: group } = await admin
    .from("family_groups").select("id, name").eq("id", invite.group_id).single();

  return json({
    ok: true,
    group_id: invite.group_id,
    group_name: group?.name ?? null,
  });
});
