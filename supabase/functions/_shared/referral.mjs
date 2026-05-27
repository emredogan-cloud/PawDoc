// Maps a claim_referral() RPC status to a client-facing result. Single source of
// truth so the Edge Function response and the app message/analytics stay in sync.
// Plain ESM so it runs in Deno (the Edge Function) and Node (the unit test).

/** A claim outcome that is a fraud attempt (self-referral or double-claim). */
export function isFraudStatus(status) {
  return status === "self_referral" || status === "already_claimed";
}

export function referralResult(status) {
  switch (status) {
    case "success":
      return {
        ok: true,
        status,
        message: "Reward claimed! You and your friend each earned 3 bonus checks.",
      };
    case "self_referral":
      return { ok: false, status, message: "You can't use your own referral code." };
    case "already_claimed":
      return { ok: false, status, message: "You've already claimed a referral code." };
    case "invalid_code":
      return { ok: false, status, message: "That referral code isn't valid." };
    default:
      return { ok: false, status: "error", message: "Something went wrong. Please try again." };
  }
}
