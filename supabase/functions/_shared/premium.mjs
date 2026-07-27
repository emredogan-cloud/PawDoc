// The one definition of "this user has premium access", shared by every server
// surface that gates on it (analyze, assistant-chat, generate-pdf-report) and
// mirrored on the client in mobile/lib/src/account/user_profile.dart.
//
// Premium is normally granted by a RevenueCat purchase: the webhook writes
// `users.subscription_status`. `internal_tester` is the one exception — a
// permanent grant for PawDoc's own QA account, applied with the service role
// only. It is deliberately a *distinct* status rather than a plain "premium"
// row so support, analytics and revenue reporting can tell an internal tester
// apart from a paying customer at a glance.
//
// Why this is not a bypass:
//   * The client cannot set it. `authenticated` holds no UPDATE grant on
//     public.users at all, so a self-PATCH fails with 42501 before RLS is even
//     consulted (verified against the live database).
//   * It is per-row, not a flag. No code path turns it on for anyone else, and
//     there is no "if debug then premium" branch anywhere.
//   * The purchase flow is untouched. Ordinary accounts still buy, still get
//     `premium` from the webhook, still restore through RevenueCat.
//
// Granting/revoking: docs/runbooks/INTERNAL_TEST_ACCOUNT.md.

/** Service-role-only permanent grant for the internal QA account. */
export const INTERNAL_TESTER_STATUS = "internal_tester";

/** One plan — premium, the store trial period, and the internal QA grant. */
export const PREMIUM_STATUSES = new Set([
  "premium",
  "trial",
  INTERNAL_TESTER_STATUS,
]);

export function isPremiumStatus(status) {
  return PREMIUM_STATUSES.has(String(status ?? ""));
}
