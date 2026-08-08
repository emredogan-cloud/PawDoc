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

  /// What a weekly plan costs over a year, stated so the arithmetic is visible.
  ///
  /// A weekly plan is the most expensive way to buy a year of anything, and a
  /// plan ladder that hides it is a ladder designed to mislead. So the weekly
  /// card carries its own annualised figure — but the wording is the whole
  /// point, and it is why this returns a *sentence* rather than a number:
  ///
  ///   * it names the multiplier — **"52 weeks at this price is ≈ …"** — so the
  ///     reader can check it, rather than trusting an unexplained "$207/year";
  ///   * 52 weeks is exactly 364 days, so the claim is arithmetically true as
  ///     stated. It is *not* dressed up as "per year", which would be 52.18
  ///     billing periods and would overstate nothing but understate the cost;
  ///   * it is a **cost** statement, never a "you save" statement — the saving
  ///     belongs to the annual card, computed against the monthly plan, which
  ///     is the comparison a subscriber would actually make.
  ///
  /// Returns null when the figure cannot be produced honestly: no price, a
  /// non-positive price, or no currency to format it in. The card then says
  /// only "Billed weekly", which is true and complete.
  static String? weeklyAnnualisedNote({
    required double? weeklyPrice,
    required String? currencySymbolSource,
  }) {
    if (weeklyPrice == null || weeklyPrice <= 0) return null;
    final formatted = formatLike(currencySymbolSource, weeklyPrice * 52);
    return formatted == null
        ? null
        : '52 weeks at this price is ≈ $formatted';
  }

  /// Formats [amount] using the store's own price string as the template.
  ///
  /// The store returns e.g. `"₺149,99"`, `"$3.99"` or `"3,99 €"`. Rather than
  /// guessing a locale, the digits are lifted out of that template and replaced
  /// — so the currency symbol, its position, and the decimal separator all stay
  /// exactly as the store wrote them. Returns null when the template carries no
  /// recognisable number, because a figure printed in the wrong currency is
  /// worse than no figure.
  static String? formatLike(String? template, double amount) {
    if (template == null || template.isEmpty) return null;
    final match = RegExp(r'\d[\d., \s]*\d|\d').firstMatch(template);
    if (match == null) return null;
    final sample = match.group(0)!;
    // Whichever of . or , appears LAST in the sample is that locale's decimal
    // separator; the other one groups thousands.
    final lastDot = sample.lastIndexOf('.');
    final lastComma = sample.lastIndexOf(',');
    final decimalSep = lastComma > lastDot ? ',' : '.';
    final groupSep = decimalSep == ',' ? '.' : ',';
    final hasDecimals = sample.contains(decimalSep) &&
        sample.length - sample.lastIndexOf(decimalSep) - 1 == 2;

    final fixed = amount.toStringAsFixed(hasDecimals ? 2 : 0);
    final parts = fixed.split('.');
    final grouped = _group(parts.first, groupSep);
    final rendered =
        parts.length > 1 ? '$grouped$decimalSep${parts[1]}' : grouped;
    return template.replaceRange(match.start, match.end, rendered);
  }

  static String _group(String digits, String separator) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(separator);
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
