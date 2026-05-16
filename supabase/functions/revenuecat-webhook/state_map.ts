// State mapping for the RevenueCat webhook.
//
// The mapping is its own module so unit tests can exercise it without
// booting the full edge function runtime.

import { optionalEnv } from "../_shared/env.ts";

export type SubscriptionStatus = "free" | "trial" | "premium" | "family";

export type SubscriptionUpdate = {
  /** Replace the user's status. */
  status: SubscriptionStatus;
  /** The RevenueCat product id we matched, persisted to subscription_tier. */
  tier: string;
} | {
  /** Leave the user's subscription_status unchanged. Used for log-only events. */
  status: null;
  reason: string;
};

export interface IncomingEvent {
  type: string;
  productId: string | null;
}

/**
 * Look up the `<tier, period>` for a RevenueCat product id by checking
 * each of the four env vars. Unknown products map to "premium" with the
 * raw product id as the tier — defensive default so an experimentation
 * SKU doesn't accidentally downgrade users.
 */
export function productTier(productId: string | null): {
  status: SubscriptionStatus;
  tier: string;
} {
  if (!productId) {
    return { status: "premium", tier: "unknown" };
  }
  const premMonthly = optionalEnv("REVENUECAT_PRODUCT_PREMIUM_MONTHLY");
  const premAnnual = optionalEnv("REVENUECAT_PRODUCT_PREMIUM_ANNUAL");
  const famMonthly = optionalEnv("REVENUECAT_PRODUCT_FAMILY_MONTHLY");
  const famAnnual = optionalEnv("REVENUECAT_PRODUCT_FAMILY_ANNUAL");

  if (productId === famMonthly || productId === famAnnual) {
    return { status: "family", tier: productId };
  }
  if (productId === premMonthly || productId === premAnnual) {
    return { status: "premium", tier: productId };
  }
  // Unknown product — fail "safe" by granting premium rather than
  // downgrading an actual paying customer because we typo'd the env.
  return { status: "premium", tier: productId };
}

/**
 * Decide what (if anything) to write to public.users based on the inbound
 * RevenueCat event. Returns null when no change is required.
 */
export function deriveUpdate(event: IncomingEvent): SubscriptionUpdate {
  const upgrade = (): SubscriptionUpdate => {
    const { status, tier } = productTier(event.productId);
    return { status, tier };
  };

  switch (event.type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
    case "UNCANCELLATION":
    case "SUBSCRIPTION_EXTENDED":
      return upgrade();

    case "EXPIRATION":
    case "BILLING_ISSUE":
      return { status: "free", tier: "" };

    case "CANCELLATION":
      // User clicked "cancel" — entitlement remains active until
      // expires_date. Wait for EXPIRATION to downgrade.
      return { status: null, reason: "cancellation_pending_expiration" };

    case "NON_RENEWING_PURCHASE":
      // One-time IAP, not a subscription. Phase 1D doesn't model these.
      return { status: null, reason: "non_renewing_ignored" };

    case "SUBSCRIPTION_PAUSED":
      // Pause is an Android-specific state. We treat as "still entitled"
      // until pause resolves into either RESUME or EXPIRATION.
      return { status: null, reason: "subscription_paused" };

    case "TRANSFER":
      // Account-level transfer between users. Phase 2 implements.
      return { status: null, reason: "transfer_unhandled" };

    case "TEST":
      // RevenueCat dashboard sends TEST events; ack but make no change.
      return { status: null, reason: "test_event" };

    default:
      return { status: null, reason: `unknown_event:${event.type}` };
  }
}
