// Maps a RevenueCat webhook event to a PawDoc subscription_status, or null when
// the event implies no status change (e.g. CANCELLATION keeps access until
// EXPIRATION). Pure -> unit-testable.
//
// Phase 5.4 — RevenueCat ENTITLEMENT IDs ("family" / "b2b_lite") promote into
// the matching subscription_status. Anything else with an active period keeps
// the legacy "premium" tier so existing customers don't lose access.
const TIER_ENTITLEMENTS = new Set(["family", "b2b_lite"]);

function paidStatusFor(event) {
  // Prefer the entitlement identifier(s) RevenueCat sends with the event.
  const ids = event?.entitlement_ids;
  if (Array.isArray(ids)) {
    for (const id of ids) {
      if (TIER_ENTITLEMENTS.has(id)) return id;
    }
  }
  const singleId = event?.entitlement_id;
  if (typeof singleId === "string" && TIER_ENTITLEMENTS.has(singleId)) return singleId;
  return "premium";
}

export function entitlementStatusFromEvent(event) {
  const type = event?.type;
  const period = event?.period_type;
  switch (type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
    case "PRODUCT_CHANGE":
      return period === "TRIAL" ? "trial" : paidStatusFor(event);
    case "EXPIRATION":
      return "free";
    default:
      // CANCELLATION, BILLING_ISSUE, TRANSFER, etc.: access unchanged here.
      return null;
  }
}
