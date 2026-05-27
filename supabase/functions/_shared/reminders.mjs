// Pure helpers for /process-reminders (Phase 3.3 Part 2). Plain ESM so it runs
// in Deno (the Edge Function) and Node (the unit test).

/**
 * Validate the cron secret in constant time. Fails CLOSED: an empty/unset
 * expected secret rejects everything, so a misconfigured deploy can never be
 * triggered to blast notifications.
 */
export function cronSecretValid(provided, expected) {
  if (typeof expected !== "string" || expected.length === 0) return false;
  if (typeof provided !== "string" || provided.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= provided.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return diff === 0;
}

/** Wrap a notification in the OneSignal request body. */
export function oneSignalBody(appId, notification) {
  return { app_id: appId, ...notification };
}

/** Push for a due health reminder (the reminder_type is the user's label). */
export function reminderNotification(reminder) {
  return {
    include_player_ids: [reminder.player_id],
    headings: { en: "Pet health reminder" },
    contents: { en: `Reminder: ${reminder.reminder_type}` },
    data: { type: "reminder", reminder_id: reminder.id, pet_id: reminder.pet_id },
  };
}

/** Gentle inactivity "we miss you" push. */
export function reengagementNotification(playerId) {
  return {
    include_player_ids: [playerId],
    headings: { en: "We miss you 🐾" },
    contents: { en: "How is your pet doing? A quick health check is just a tap away." },
    data: { type: "reengagement" },
  };
}
