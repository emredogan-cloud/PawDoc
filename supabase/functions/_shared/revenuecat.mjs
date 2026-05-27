// Maps a RevenueCat webhook event to a PawDoc subscription_status, or null when
// the event implies no status change (e.g. CANCELLATION keeps access until
// EXPIRATION). Pure -> unit-testable.
export function entitlementStatusFromEvent(event) {
  const type = event?.type;
  const period = event?.period_type;
  switch (type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
    case "PRODUCT_CHANGE":
      return period === "TRIAL" ? "trial" : "premium";
    case "EXPIRATION":
      return "free";
    default:
      // CANCELLATION, BILLING_ISSUE, TRANSFER, etc.: access unchanged here.
      return null;
  }
}
