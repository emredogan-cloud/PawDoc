import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/monetization/paywall_pricing.dart';

/// Regression cover for the paywall pricing bug found on-device 2026-07-27.
///
/// The annual package failed to resolve from RevenueCat while the monthly one
/// succeeded. The paywall substituted a hardcoded USD fallback, so a Turkish
/// tester saw "Annual $39.99/year" stacked on "Monthly ₺569,99" with a constant
/// "Save 52%" badge — two currencies, and a savings claim that was arithmetic
/// against neither of them.
///
/// The rule these tests pin: every figure on the paywall is derived from the
/// store's own numbers, and a claim that cannot be computed is not made.
void main() {
  group('savingsBadge', () {
    test('computes the real percentage when both plans share a currency', () {
      // 39.99/yr vs 6.99/mo (=83.88/yr) -> 52.3% -> "Save 52%"
      expect(
        PaywallPricing.savingsBadge(
          annualPrice: 39.99,
          annualCurrency: 'USD',
          monthlyPrice: 6.99,
          monthlyCurrency: 'USD',
        ),
        'Save 52%',
      );
    });

    test('recomputes for a different store currency rather than reusing 52%', () {
      // 1499.99/yr vs 569.99/mo (=6839.88/yr) -> 78.07% -> "Save 78%"
      expect(
        PaywallPricing.savingsBadge(
          annualPrice: 1499.99,
          annualCurrency: 'TRY',
          monthlyPrice: 569.99,
          monthlyCurrency: 'TRY',
        ),
        'Save 78%',
      );
    });

    test('returns null across mismatched currencies — the bug that shipped', () {
      expect(
        PaywallPricing.savingsBadge(
          annualPrice: 39.99,
          annualCurrency: 'USD',
          monthlyPrice: 569.99,
          monthlyCurrency: 'TRY',
        ),
        isNull,
      );
    });

    test('returns null when the monthly plan did not load', () {
      expect(
        PaywallPricing.savingsBadge(
          annualPrice: 39.99,
          annualCurrency: 'USD',
          monthlyPrice: null,
          monthlyCurrency: null,
        ),
        isNull,
      );
    });

    test('claims nothing when annual is not actually cheaper', () {
      expect(
        PaywallPricing.savingsBadge(
          annualPrice: 90.00,
          annualCurrency: 'USD',
          monthlyPrice: 6.99,
          monthlyCurrency: 'USD',
        ),
        isNull,
      );
      // Exactly 12x the monthly rate is not a saving either.
      expect(
        PaywallPricing.savingsBadge(
          annualPrice: 83.88,
          annualCurrency: 'USD',
          monthlyPrice: 6.99,
          monthlyCurrency: 'USD',
        ),
        isNull,
      );
    });

    test('suppresses a sub-1% rounding artefact instead of showing "Save 0%"', () {
      expect(
        PaywallPricing.savingsBadge(
          annualPrice: 83.80,
          annualCurrency: 'USD',
          monthlyPrice: 6.99,
          monthlyCurrency: 'USD',
        ),
        isNull,
      );
    });

    test('returns null on a zero or negative monthly price', () {
      expect(
        PaywallPricing.savingsBadge(
          annualPrice: 39.99,
          annualCurrency: 'USD',
          monthlyPrice: 0,
          monthlyCurrency: 'USD',
        ),
        isNull,
      );
    });
  });

  group('annualSubtitle', () {
    test("uses the store's own localized per-month string", () {
      expect(
        PaywallPricing.annualSubtitle('₺124,99'),
        'About ₺124,99/month, billed yearly',
      );
    });

    test('falls back to a claim-free line when the store supplies none', () {
      expect(PaywallPricing.annualSubtitle(null), 'Billed yearly');
      expect(PaywallPricing.annualSubtitle(''), 'Billed yearly');
      expect(PaywallPricing.annualSubtitle('   '), 'Billed yearly');
    });

    test('never invents a hardcoded dollar figure', () {
      expect(PaywallPricing.annualSubtitle(null), isNot(contains(r'$')));
      expect(PaywallPricing.annualSubtitle(null), isNot(contains('3.33')));
    });
  });
}
