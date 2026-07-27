/// Pure pricing arithmetic for the paywall.
///
/// Deliberately free of the RevenueCat SDK types: the paywall passes in plain
/// numbers and currency codes taken from `StoreProduct`, so this logic is
/// directly unit-testable and the rules below are pinned by tests.
///
/// The rule these functions exist to enforce: **every figure shown on the
/// paywall is derived from what the store actually returned.** A price, a
/// per-month equivalent, or a savings percentage that we made up is a price we
/// would not charge — which is a store-policy and consumer-protection problem,
/// not a cosmetic one.
class PaywallPricing {
  const PaywallPricing._();

  /// Subtitle for the annual card.
  ///
  /// [pricePerMonthString] is the store's OWN localized per-month figure
  /// (`StoreProduct.pricePerMonthString`), so both the currency and the
  /// division are the store's. When the store doesn't supply one, we say only
  /// what we can stand behind rather than computing a figure ourselves.
  static String annualSubtitle(String? pricePerMonthString) {
    final perMonth = pricePerMonthString?.trim();
    return (perMonth == null || perMonth.isEmpty)
        ? 'Billed yearly'
        : 'About $perMonth/month, billed yearly';
  }

  /// Saving of the annual plan against paying the monthly plan for a year.
  ///
  /// Returns null — meaning "show no badge" — unless the claim is genuinely
  /// computable and true:
  ///   * both plans loaded (no monthly ⇒ nothing to compare against),
  ///   * both are priced in the SAME currency (cross-currency arithmetic is
  ///     meaningless without an exchange rate we don't have),
  ///   * the monthly price is positive, and
  ///   * the annual plan actually costs less, by at least 1%.
  static String? savingsBadge({
    required double annualPrice,
    required String annualCurrency,
    required double? monthlyPrice,
    required String? monthlyCurrency,
  }) {
    if (monthlyPrice == null || monthlyCurrency == null) return null;
    if (annualCurrency != monthlyCurrency) return null;
    final twelveMonths = monthlyPrice * 12;
    if (twelveMonths <= 0) return null;
    if (annualPrice >= twelveMonths) return null;
    final pct = ((1 - annualPrice / twelveMonths) * 100).round();
    return pct >= 1 ? 'Save $pct%' : null;
  }
}
