/// Tests for the RevenueCat service — graceful no-op when no key.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/shared/services/revenuecat_service.dart';

void main() {
  group('NoopRevenueCatService', () {
    const noop = NoopRevenueCatService();

    test('reports as not enabled', () {
      expect(noop.isEnabled, isFalse);
    });

    test('initialize is a no-op', () async {
      await noop.initialize();
    });

    test('identify is a no-op', () async {
      await noop.identify('user-1');
    });

    test('getOfferings returns empty list', () async {
      expect(await noop.getOfferings(), isEmpty);
    });

    test('restore returns notSupported', () async {
      final outcome = await noop.restore();
      expect(outcome.kind, PurchaseOutcomeKind.notSupported);
    });

    // Note: NoopRevenueCatService.purchase requires a real Package which
    // we can't construct without the platform plugin. The paywall
    // controller test exercises the abstract RevenueCatService interface
    // directly with a hand-rolled fake instead.

    test('logOut is a no-op', () async {
      await noop.logOut();
    });
  });

  group('PurchaseOutcomeKind copy', () {
    test('every kind except success/userCancelled has user-visible copy', () {
      for (final kind in PurchaseOutcomeKind.values) {
        if (kind == PurchaseOutcomeKind.success ||
            kind == PurchaseOutcomeKind.userCancelled) {
          expect(kind.userMessage, isEmpty);
        } else {
          expect(kind.userMessage, isNotEmpty);
        }
      }
    });

    test('copy never leaks backend identifiers', () {
      const taboo = ['supabase', 'http', 'sentry', 'fastapi', 'exception'];
      for (final kind in PurchaseOutcomeKind.values) {
        final m = kind.userMessage.toLowerCase();
        for (final t in taboo) {
          expect(
            m.contains(t),
            isFalse,
            reason: '$kind leaked "$t": ${kind.userMessage}',
          );
        }
      }
    });
  });

  test('PurchaseOutcome success bool reflects kind', () {
    expect(const PurchaseOutcome(PurchaseOutcomeKind.success).success, isTrue);
    expect(const PurchaseOutcome(PurchaseOutcomeKind.network).success, isFalse);
  });
}
