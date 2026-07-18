// PDF Health Report client-side entitlement test. Mirrors the server-side gate
// in supabase/functions/generate-pdf-report/index.ts (premium-included; no
// consumable credits) so the UI and the Edge can't disagree silently.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';

void main() {
  group('PDF entitlement (premium-included)', () {
    test('premium and trial unlock', () {
      for (final tier in ['premium', 'trial']) {
        expect(
          UserProfile(subscriptionStatus: tier, photoLogsUsedThisMonth: 0).isPremium,
          isTrue,
          reason: '$tier should unlock',
        );
      }
    });

    test('free is gated (no credit-pack path exists)', () {
      const u = UserProfile(subscriptionStatus: 'free', photoLogsUsedThisMonth: 0);
      expect(u.isPremium, isFalse);
    });

    test('retired tier names no longer unlock premium', () {
      for (final tier in ['family', 'b2b_lite']) {
        expect(
          UserProfile(subscriptionStatus: tier, photoLogsUsedThisMonth: 0).isPremium,
          isFalse,
          reason: '$tier was removed in the one-plan collapse',
        );
      }
    });
  });
}
