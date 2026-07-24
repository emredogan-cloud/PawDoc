// Phase 1.2 — /generate-upload-url
// Mints a SHORT-LIVED presigned R2 PUT URL so the client can upload directly to
// Cloudflare R2 WITHOUT ever holding R2 write credentials (CR #6). The R2 keys
// live only in this function's env. verify_jwt stays default (true): the app
// calls this authenticated, and the key is namespaced under the caller's id.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.20";
// deno-lint-ignore no-import-assertions
import { buildStorageKey } from "../_shared/upload_key.mjs";

const PRESIGN_TTL_SECONDS = 300;

Deno.serve(async (req: Request) => {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json" },
    });

  // Authenticated caller (RLS-scoped client just to resolve the user).
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
    // body is optional; defaults below
  }

  // Next Evolution Phase 2: optional purpose scope (uploads | memories | chat).
  // buildStorageKey validates it against the allowlist; default stays uploads/
  // so the analysis capture flow is unchanged.
  let key: string;
  try {
    key = buildStorageKey(user.id, body.ext ?? "jpg", crypto.randomUUID(), body.scope ?? "uploads");
  } catch (e) {
    return json({ error: String(e) }, 400);
  }

  const accountId = Deno.env.get("R2_ACCOUNT_ID");
  const bucket = Deno.env.get("R2_BUCKET");
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
  if (!accountId || !bucket || !accessKeyId || !secretAccessKey) {
    return json({ error: "storage not configured" }, 500);
  }

  const r2 = new AwsClient({ accessKeyId, secretAccessKey, service: "s3", region: "auto" });
  const target = new URL(`https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`);
  target.searchParams.set("X-Amz-Expires", String(PRESIGN_TTL_SECONDS));

  // signQuery: presign into the query string (a PUT URL the client can use directly).
  const signed = await r2.sign(new Request(target.toString(), { method: "PUT" }), {
    aws: { signQuery: true },
  });

  return json({ url: signed.url, key, expires_in: PRESIGN_TTL_SECONDS });
});
