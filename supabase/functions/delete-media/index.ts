// Next Evolution Phase 2 — /delete-media
// Deletes ONE R2 object from the caller's own journal namespace after the app
// has removed the owning row (RLS-scoped delete). Best-effort by design: the
// row delete is the source of truth; a failed object delete only leaves an
// orphaned private object, which the delete-account purge sweeps later.
//
// Scope rules (single source of truth: _shared/upload_key.mjs):
//   - only DELETABLE_SCOPES (memories/) may be deleted here — analysis inputs
//     (uploads/) and chat attachments are lifecycle-managed elsewhere;
//   - the key must be namespaced under the CALLING user's id.
// verify_jwt stays default (true).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.20";
// deno-lint-ignore no-import-assertions
import { DELETABLE_SCOPES, isOwnMediaKey } from "../_shared/upload_key.mjs";

Deno.serve(async (req: Request) => {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json" },
    });

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

  // deno-lint-ignore no-explicit-any
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid body" }, 400);
  }

  const key = body.key;
  if (!isOwnMediaKey(key, user.id, DELETABLE_SCOPES)) {
    return json({ error: "invalid key" }, 400);
  }

  const accountId = Deno.env.get("R2_ACCOUNT_ID");
  const bucket = Deno.env.get("R2_BUCKET");
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
  if (!accountId || !bucket || !accessKeyId || !secretAccessKey) {
    // Storage unconfigured (dev): the row is gone, nothing to delete.
    return json({ ok: true, deleted: false });
  }

  const r2 = new AwsClient({ accessKeyId, secretAccessKey, service: "s3", region: "auto" });
  const target = `https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`;
  const resp = await r2.fetch(target, { method: "DELETE" });
  const ok = resp.ok || resp.status === 404;
  if (!ok) {
    console.error("delete-media: R2 delete failed", resp.status);
  }
  return json({ ok: true, deleted: ok });
});
