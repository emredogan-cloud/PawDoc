// Assistant-chat pure-logic tests.
// Run: node --test supabase/functions/_shared/assistant_chat.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import {
  ASSISTANT_FREE_DAILY_LIMIT,
  assistantBlocked,
  deriveConversationTitle,
  isPremiumStatus,
  MAX_ASSISTANT_MESSAGE_CHARS,
  validateAssistantBody,
  windowMessages,
} from "./assistant_chat.mjs";

test("premium statuses match the one-plan contract", () => {
  assert.equal(isPremiumStatus("premium"), true);
  assert.equal(isPremiumStatus("trial"), true);
  assert.equal(isPremiumStatus("free"), false);
  assert.equal(isPremiumStatus(undefined), false);
});

test("free users block at the daily limit; premium never blocks", () => {
  assert.equal(assistantBlocked(ASSISTANT_FREE_DAILY_LIMIT - 1, false), false);
  assert.equal(assistantBlocked(ASSISTANT_FREE_DAILY_LIMIT, false), true);
  assert.equal(assistantBlocked(9999, true), false);
});

test("title derivation: single line, word-safe cut, ellipsis", () => {
  assert.equal(deriveConversationTitle("  Hello\nworld  "), "Hello world");
  assert.equal(deriveConversationTitle(""), "New conversation");
  const long = "How often should I really brush my golden retriever every week";
  const title = deriveConversationTitle(long);
  assert.ok(title.endsWith("…"));
  assert.ok(title.length <= 49);
  assert.ok(!title.includes("retriev "), "cuts on a word boundary");
});

test("body validation normalizes and rejects malformed input", () => {
  const ok = validateAssistantBody({
    message: "  hi there  ",
    conversation_id: "11111111-1111-1111-1111-111111111111",
    pet_id: null,
    image_storage_key: null,
  });
  assert.equal(ok.ok, true);
  assert.equal(ok.value.message, "hi there");
  assert.equal(ok.value.petId, null);

  assert.equal(validateAssistantBody(null).ok, false);
  assert.equal(validateAssistantBody({}).ok, false);
  assert.equal(
    validateAssistantBody({ message: "x".repeat(MAX_ASSISTANT_MESSAGE_CHARS + 1) }).ok,
    false,
  );
  assert.equal(
    validateAssistantBody({ message: "hi", conversation_id: "not-a-uuid" }).ok,
    false,
  );
  assert.equal(
    validateAssistantBody({ message: "hi", pet_id: "../../etc" }).ok,
    false,
  );
});

test("windowMessages keeps the newest tail", () => {
  const msgs = Array.from({ length: 30 }, (_, i) => ({ role: "user", content: `m${i}` }));
  const windowed = windowMessages(msgs, 20);
  assert.equal(windowed.length, 20);
  assert.equal(windowed[0].content, "m10");
  assert.equal(windowed[19].content, "m29");
  assert.deepEqual(windowMessages("junk"), []);
});
