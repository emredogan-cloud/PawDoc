// Phase 6.3.1 — pure helpers for the invite + accept Edge Functions.

// Tiers that may issue family invites. Premium ($14.99) is excluded by design —
// upgrading to Family ($24.99) is the upsell that unlocks sharing.
export const INVITE_ELIGIBLE_TIERS = new Set(["family", "b2b_lite"]);

// 32 URL-safe random bytes -> a 43-char base64url token. crypto.getRandomValues
// is part of Deno's web platform, so this works inside Edge Functions too.
export function generateInviteToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  // base64url without padding
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

// Lower-case + trim — emails are matched case-insensitively.
export function normalizeEmail(input) {
  if (!input || typeof input !== "string") return null;
  const trimmed = input.trim().toLowerCase();
  return trimmed.includes("@") ? trimmed : null;
}

// inviteLink(base, token) — defaults to the canonical https://pawdoc.app/invite
// path when no override is provided. Universal-link configuration on iOS +
// the Android app-link intent-filter route this URL into the running app;
// the cold-launch path lands on /invite/:token in go_router.
export function inviteLink(base, token) {
  const root = (base ?? "https://pawdoc.app/invite").replace(/\/+$/, "");
  return `${root}/${encodeURIComponent(token)}`;
}

// Pure formatter for the Resend email payload — keeps the network call dumb.
export function buildInviteEmail({ to, link, inviterName, groupName }) {
  const subject = `${inviterName || "Someone"} invited you to share their pets on PawDoc`;
  const text = [
    "Hi,",
    "",
    `${inviterName || "A PawDoc user"} has invited you to join the "${
      groupName || "Family"
    }" household on PawDoc — so you can share pet check-ins, history, and reminders.`,
    "",
    `Accept the invite here (link expires in 48 hours):`,
    link,
    "",
    "If you don't have PawDoc yet, the link will open the App Store / Play Store first.",
    "",
    "— PawDoc",
  ].join("\n");
  return { to, subject, text };
}
