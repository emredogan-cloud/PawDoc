// Next Evolution Phase 4 — /assistant-chat
// The conversational assistant's only door: verifies the user JWT, runs the
// EMERGENCY keyword check FIRST (before quota, before any persistence — an
// emergency message is never counted, never blocked, never sent to a model),
// enforces the free daily allowance, persists the exchange, and streams the
// model reply from the internal AI service through to the client as SSE.
//
// Trust boundary mirrors /analyze: the client never talks to the AI service
// or holds provider keys; images reach the model only as short-lived presigned
// GETs of the caller's OWN chat/ uploads (GAP-A2 posture).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.20";
// deno-lint-ignore no-import-assertions
import { aiServiceHeaders } from "../_shared/ai_service.mjs";
// deno-lint-ignore no-import-assertions
import { containsEmergencyKeyword } from "../_shared/emergency_keywords.mjs";
// deno-lint-ignore no-import-assertions
import { isOwnMediaKey } from "../_shared/upload_key.mjs";
// deno-lint-ignore no-import-assertions
import {
  ASSISTANT_FREE_DAILY_LIMIT,
  ASSISTANT_HISTORY_WINDOW,
  assistantBlocked,
  deriveConversationTitle,
  isPremiumStatus,
  validateAssistantBody,
  windowMessages,
} from "../_shared/assistant_chat.mjs";

const AI_SERVICE_URL = Deno.env.get("AI_SERVICE_URL") ?? "https://pawdoc-ai.fly.dev";
const AI_SERVICE_TOKEN = Deno.env.get("AI_SERVICE_TOKEN") ?? "";
const UPSTREAM_TIMEOUT_MS = 60_000; // whole-stream budget
const IMAGE_PRESIGN_TTL = 120;

function sseFrame(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

function sseResponse(body: BodyInit, extra: Record<string, string> = {}): Response {
  return new Response(body, {
    headers: {
      "content-type": "text/event-stream",
      "cache-control": "no-cache",
      ...extra,
    },
  });
}

async function presignChatImage(key: string): Promise<string | null> {
  const accountId = Deno.env.get("R2_ACCOUNT_ID");
  const bucket = Deno.env.get("R2_BUCKET");
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");
  if (!accountId || !bucket || !accessKeyId || !secretAccessKey) return null;
  const r2 = new AwsClient({ accessKeyId, secretAccessKey, service: "s3", region: "auto" });
  const target = new URL(`https://${accountId}.r2.cloudflarestorage.com/${bucket}/${key}`);
  target.searchParams.set("X-Amz-Expires", String(IMAGE_PRESIGN_TTL));
  const signed = await r2.sign(new Request(target.toString(), { method: "GET" }), {
    aws: { signQuery: true },
  });
  return signed.url;
}

Deno.serve(async (req: Request) => {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json" },
    });
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();

  // --- 1. Authenticated caller (RLS-scoped client). --------------------------
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

  // --- 2. Validate input. -----------------------------------------------------
  // deno-lint-ignore no-explicit-any
  let raw: any = {};
  try {
    raw = await req.json();
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  const parsed = validateAssistantBody(raw);
  if (!parsed.ok) return json({ error: parsed.error }, 400);
  const { message, conversationId, petId, imageKey } = parsed.value;

  if (imageKey !== null && !isOwnMediaKey(imageKey, user.id, ["chat"])) {
    // Foreign / non-chat-scope keys are refused outright (GAP-A2 posture).
    return json({ error: "invalid image key" }, 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // --- 3. Locale + pet context (RLS-scoped pet read). -------------------------
  let locale = "en";
  let subscriptionStatus = "free";
  try {
    const { data: profile } = await admin
      .from("users")
      .select("preferred_locale, subscription_status")
      .eq("id", user.id)
      .single();
    locale = profile?.preferred_locale ?? "en";
    subscriptionStatus = profile?.subscription_status ?? "free";
  } catch {
    // Best-effort — defaults hold.
  }

  // deno-lint-ignore no-explicit-any
  let pet: any = null;
  if (petId) {
    const { data: petRow } = await userClient
      .from("pets")
      .select("id, name, species, breed, birth_date, sex, weight_kg")
      .eq("id", petId)
      .single();
    if (!petRow) return json({ error: "pet not found" }, 404);
    let ageYears: number | null = null;
    if (petRow.birth_date) {
      const born = new Date(petRow.birth_date).getTime();
      if (!Number.isNaN(born)) {
        ageYears = Math.max(0, Math.floor((Date.now() - born) / (365.25 * 24 * 3600 * 1000)));
      }
    }
    pet = {
      species: petRow.species,
      breed: petRow.breed,
      age_years: ageYears,
      sex: petRow.sex,
      weight_kg: petRow.weight_kg,
    };
  }

  // --- 4. EMERGENCY FIRST — before quota, before persistence, before AI. ------
  if (containsEmergencyKeyword(message, pet?.species, locale)) {
    return sseResponse(sseFrame("emergency", { locale }));
  }

  // --- 5. Free daily allowance (premium unlimited; server-enforced). ----------
  const isPremium = isPremiumStatus(subscriptionStatus);
  if (!isPremium) {
    const dayStart = new Date();
    dayStart.setUTCHours(0, 0, 0, 0);
    const { count } = await admin
      .from("assistant_messages")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("role", "user")
      .gte("created_at", dayStart.toISOString());
    if (assistantBlocked(count ?? 0, isPremium)) {
      return json(
        { error: "assistant_limit_reached", limit: ASSISTANT_FREE_DAILY_LIMIT },
        402,
      );
    }
  }

  // --- 6. Conversation + user message (user-scoped writes; RLS enforced). -----
  let convId = conversationId;
  if (convId) {
    const { data: conv } = await userClient
      .from("assistant_conversations")
      .select("id")
      .eq("id", convId)
      .single();
    if (!conv) return json({ error: "conversation not found" }, 404);
  } else {
    const { data: conv, error: convErr } = await userClient
      .from("assistant_conversations")
      .insert({
        user_id: user.id,
        pet_id: petId,
        title: deriveConversationTitle(message),
      })
      .select("id")
      .single();
    if (convErr || !conv) return json({ error: "could not start conversation" }, 500);
    convId = conv.id as string;
  }

  const { error: msgErr } = await userClient.from("assistant_messages").insert({
    conversation_id: convId,
    user_id: user.id,
    role: "user",
    content: message,
    image_storage_key: imageKey,
  });
  if (msgErr) return json({ error: "could not save message" }, 500);

  // --- 7. Bounded history window (RLS-scoped read; includes the new turn). ----
  const { data: historyRows } = await userClient
    .from("assistant_messages")
    .select("role, content, created_at")
    .eq("conversation_id", convId)
    .order("created_at", { ascending: true })
    .limit(200);
  const history = windowMessages(
    (historyRows ?? []).map((m) => ({ role: m.role, content: m.content })),
    ASSISTANT_HISTORY_WINDOW,
  );

  const imageUrl = imageKey ? await presignChatImage(imageKey) : null;

  // --- 8. Stream from the internal AI service, tee-persisting the reply. ------
  let upstream: Response;
  try {
    upstream = await fetch(`${AI_SERVICE_URL}/assistant/chat`, {
      method: "POST",
      headers: aiServiceHeaders(requestId, AI_SERVICE_TOKEN),
      body: JSON.stringify({
        messages: history,
        pet,
        image_url: imageUrl,
        locale,
      }),
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    });
  } catch {
    return json({ error: "assistant_unavailable" }, 503);
  }
  if (!upstream.ok || !upstream.body) {
    return json({ error: "assistant_unavailable" }, 503);
  }

  // Pass bytes through untouched while accumulating the reply text; persist on
  // a clean `done`. (On a mid-stream drop the user turn stays, the reply is
  // simply re-asked — never a half-persisted hallucination.)
  const decoder = new TextDecoder();
  let buffer = "";
  let assistantText = "";
  let sawDone = false;
  const tee = new TransformStream<Uint8Array, Uint8Array>({
    transform(chunk, controller) {
      controller.enqueue(chunk);
      buffer += decoder.decode(chunk, { stream: true });
      let idx: number;
      while ((idx = buffer.indexOf("\n\n")) >= 0) {
        const frame = buffer.slice(0, idx);
        buffer = buffer.slice(idx + 2);
        const lines = frame.split("\n");
        const eventLine = lines.find((l) => l.startsWith("event: "));
        const dataLine = lines.find((l) => l.startsWith("data: "));
        if (!eventLine || !dataLine) continue;
        const name = eventLine.slice("event: ".length).trim();
        try {
          const data = JSON.parse(dataLine.slice("data: ".length));
          if (name === "delta" && typeof data.text === "string") {
            assistantText += data.text;
          } else if (name === "done") {
            sawDone = true;
          }
        } catch {
          // Malformed frame — pass through, skip accounting.
        }
      }
    },
    async flush() {
      if (sawDone && assistantText) {
        await admin.from("assistant_messages").insert({
          conversation_id: convId,
          user_id: user.id,
          role: "assistant",
          content: assistantText,
        });
        await admin
          .from("assistant_conversations")
          .update({ updated_at: new Date().toISOString() })
          .eq("id", convId);
      }
    },
  });

  return sseResponse(upstream.body.pipeThrough(tee), {
    "x-conversation-id": convId!,
    "x-request-id": requestId,
  });
});
