// Maps a RevenueCat webhook event to a PawDoc subscription_status, or null when
// the event implies no status change (e.g. CANCELLATION keeps access until
// EXPIRATION). Pure -> unit-testable.
//
// Phase 5.4 — RevenueCat ENTITLEMENT IDs ("family" / "b2b_lite") promote into
// the matching subscription_status. Anything else with an active period keeps
// the legacy "premium" tier so existing customers don't lose access.
const TIER_ENTITLEMENTS = new Set(["family", "b2b_lite"]);

// Phase 6.3 — one-time consumable add-ons. The key is the RevenueCat
// product_id; the value names the column the webhook should increment and
// how many credits each purchase grants. Keep this in sync with the products
// configured in the RevenueCat dashboard.
export const ADDON_PRODUCTS = {
  pdf_report_addon: { column: "pdf_reports_remaining", delta: 1 },
};

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

// Phase 6.3 — recognize a one-time consumable purchase (e.g. the $4.99 PDF
// Health Report). Returns {column, delta} when the event matches a known
// add-on, otherwise null. The webhook is expected to apply this as a credit
// increment ON TOP OF (not instead of) the subscription_status mapping.
export function addonCreditsFromEvent(event) {
  if (!event) return null;
  const type = event.type;
  // RevenueCat fires NON_RENEWING_PURCHASE for consumables and one-time
  // products. We also accept INITIAL_PURCHASE in case a project chooses to
  // ship the add-on as a non-consumable — both are one-shot credit grants.
  if (type !== "NON_RENEWING_PURCHASE" && type !== "INITIAL_PURCHASE") return null;
  const productId = event.product_id ?? event.product_identifier ?? null;
  if (!productId || typeof productId !== "string") return null;
  const cfg = ADDON_PRODUCTS[productId];
  return cfg ? { ...cfg, productId } : null;
}
