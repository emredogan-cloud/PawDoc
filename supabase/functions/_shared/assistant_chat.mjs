// Pure assistant-chat logic (Next Evolution Phase 4). Plain ESM so it runs in
// Deno (the Edge Function) and Node (the unit test).
//
// Quota philosophy mirrors "free = safety, paid = memory": conversation is
// generous but bounded on free (cost control on a real model surface), premium
// is unlimited — and the EMERGENCY path is checked BEFORE quota, so an
// emergency message is never counted or blocked.

/** Free assistant messages per UTC day (user turns only). */
export const ASSISTANT_FREE_DAILY_LIMIT = 20;

/** Hard cap on one chat message (mirrors the client input limit). */
export const MAX_ASSISTANT_MESSAGE_CHARS = 2000;

/** Conversation-window size sent to the model (newest last). */
export const ASSISTANT_HISTORY_WINDOW = 20;

/** One plan: premium (plus the store trial period). Mirrors analyze/index.ts. */
export const PREMIUM_STATUSES = new Set(["premium", "trial"]);

export function isPremiumStatus(status) {
  return PREMIUM_STATUSES.has(String(status ?? ""));
}

/** True when a free user has exhausted today's allowance. Premium never blocks. */
export function assistantBlocked(todayCount, isPremium, limit = ASSISTANT_FREE_DAILY_LIMIT) {
  if (isPremium) return false;
  return Number(todayCount) >= limit;
}

/**
 * Derive a conversation title from the first user message: single line,
 * trimmed, word-safe cut at `max` chars with an ellipsis.
 */
export function deriveConversationTitle(text, max = 48) {
  const single = String(text ?? "").replace(/\s+/g, " ").trim();
  if (!single) return "New conversation";
  if (single.length <= max) return single;
  const cut = single.slice(0, max);
  const lastSpace = cut.lastIndexOf(" ");
  const base = lastSpace > max * 0.6 ? cut.slice(0, lastSpace) : cut;
  return `${base.trimEnd()}…`;
}

/**
 * Validate the inbound request body. Returns {ok:true, value} with normalized
 * fields or {ok:false, error} — never throws on user input.
 */
export function validateAssistantBody(body) {
  if (body == null || typeof body !== "object") {
    return { ok: false, error: "invalid body" };
  }
  const message = typeof body.message === "string" ? body.message.trim() : "";
  if (!message) return { ok: false, error: "message required" };
  if (message.length > MAX_ASSISTANT_MESSAGE_CHARS) {
    return { ok: false, error: "message too long" };
  }
  const uuidRe = /^[0-9a-fA-F-]{36}$/;
  const conversationId =
    body.conversation_id == null ? null : String(body.conversation_id);
  if (conversationId !== null && !uuidRe.test(conversationId)) {
    return { ok: false, error: "invalid conversation_id" };
  }
  const petId = body.pet_id == null ? null : String(body.pet_id);
  if (petId !== null && !uuidRe.test(petId)) {
    return { ok: false, error: "invalid pet_id" };
  }
  const imageKey =
    body.image_storage_key == null ? null : String(body.image_storage_key);
  return {
    ok: true,
    value: { message, conversationId, petId, imageKey },
  };
}

/**
 * Trim a chronological message list to the model window: keep the newest
 * `windowSize` turns (the final one is the new user message).
 */
export function windowMessages(messages, windowSize = ASSISTANT_HISTORY_WINDOW) {
  if (!Array.isArray(messages)) return [];
  return messages.slice(-windowSize);
}
