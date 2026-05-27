// Phase 2.1 — /delete-account (CR #9, Apple Guideline 5.1.1(v))
// Deletes the CALLING user's account. The user is taken from the verified JWT
// (never a body param), so a caller can only delete themselves. Deleting the
// auth user cascades to public.users and onward to pets/analyses/reminders/
// referrals via the ON DELETE CASCADE FKs from Phase 1.1 (CR #20).
// verify_jwt stays default (true).
import { createClient } from "jsr:@supabase/supabase-js@2";

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

  // Removes the auth user; FK cascades wipe all of their app data.
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    console.error("delete-account failed", error.message);
    return json({ error: "deletion failed" }, 500);
  }
  return json({ ok: true });
});
