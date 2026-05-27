// Reminder push-helper tests. Run: node --test supabase/functions/_shared/reminders.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import {
  cronSecretValid,
  oneSignalBody,
  reengagementNotification,
  reminderNotification,
} from "./reminders.mjs";

test("cronSecretValid matches only the exact secret", () => {
  assert.equal(cronSecretValid("s3cret", "s3cret"), true);
  assert.equal(cronSecretValid("s3cret", "s3creX"), false);
  assert.equal(cronSecretValid("wrong-length", "s3cret"), false);
});

test("cronSecretValid fails CLOSED on an empty/unset expected secret", () => {
  assert.equal(cronSecretValid("anything", ""), false);
  assert.equal(cronSecretValid("", ""), false);
  assert.equal(cronSecretValid(null, "s3cret"), false);
});

test("reminderNotification targets the player and uses the label", () => {
  const n = reminderNotification({
    id: "r1", pet_id: "p1", reminder_type: "Flea medication", player_id: "pl1",
  });
  assert.deepEqual(n.include_player_ids, ["pl1"]);
  assert.match(n.contents.en, /Flea medication/);
  assert.equal(n.data.type, "reminder");
  assert.equal(n.data.reminder_id, "r1");
});

test("reengagementNotification is tagged for analytics/routing", () => {
  const n = reengagementNotification("pl9");
  assert.deepEqual(n.include_player_ids, ["pl9"]);
  assert.equal(n.data.type, "reengagement");
});

test("oneSignalBody injects the app id", () => {
  const body = oneSignalBody("app-123", reengagementNotification("pl9"));
  assert.equal(body.app_id, "app-123");
  assert.equal(body.data.type, "reengagement");
});
