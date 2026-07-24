// Next Evolution Phase 2 — /sign-media-url
// Mints SHORT-LIVED presigned R2 GET URLs so the app can DISPLAY the caller's
// own journal/chat media. Mirrors the trust boundary of generate-upload-url:
// R2 credentials live only here; the client only ever holds a signed URL.
//
// Scope rules (single source of truth: _shared/upload_key.mjs):
//   - only DISPLAY_SCOPES (memories/, chat/) are signable — analysis images
//     under uploads/ stay non-displayable by design (GAP-A2 posture);
//   - every key must be namespaced under the CALLING user's id — a foreign or
//     malformed key is silently dropped, never signed.
// verify_jwt stays default (true).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.20";
// deno-lint-ignore no-import-assertions
import { sanitizeKeyBatch } from "../_shared/upload_key.mjs";

const PRESIGN_TTL_SECONDS = 3600; // display URLs; client caches by storage key
const MAX_KEYS_PER_REQUEST = 24;

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

  const keys = sanitizeKeyBatch(body.keys, user.id, undefined, MAX_KEYS_PER_REQUEST);

  const accountId = Deno.env.get("R2_ACCOUNT_ID");
  const bucket = Deno.env.get("R2_BUCKET");
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
  if (!accountId || !bucket || !accessKeyId || !secretAccessKey) {
    return json({ error: "storage not configured" }, 500);
  }

  const r2 = new AwsClient({ accessKeyId, secretAccessKey, service: "s3", region: "auto" });
  const urls: { key: string; url: string }[] = [];
  for (const key of keys) {
    const target = new URL(
      `https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`,
    );
    target.searchParams.set("X-Amz-Expires", String(PRESIGN_TTL_SECONDS));
    const signed = await r2.sign(new Request(target.toString(), { method: "GET" }), {
      aws: { signQuery: true },
    });
    urls.push({ key, url: signed.url });
  }

  return json({ urls, expires_in: PRESIGN_TTL_SECONDS });
});
