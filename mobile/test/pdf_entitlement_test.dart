// Phase 6.3 — PDF Health Report client-side entitlement helper test. Mirrors
// the server-side gate in supabase/functions/generate-pdf-report/index.ts so
// the UI and the Edge can't disagree silently.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/user_profile.dart';

void main() {
  group('UserProfile.canRequestPdfReport', () {
    test('premium / family / trial / b2b_lite all unlock without credits', () {
      for (final tier in ['premium', 'family', 'trial', 'b2b_lite']) {
        expect(
          UserProfile(subscriptionStatus: tier, freeUsedThisMonth: 0).canRequestPdfReport,
          isTrue,
          reason: '$tier should unlock',
        );
      }
    });

    test('free with credits >= 1 unlocks', () {
      const u = UserProfile(
        subscriptionStatus: 'free',
        freeUsedThisMonth: 0,
        pdfReportsRemaining: 1,
      );
      expect(u.canRequestPdfReport, isTrue);
    });

    test('free with no credits is gated', () {
      const u = UserProfile(subscriptionStatus: 'free', freeUsedThisMonth: 0);
      expect(u.canRequestPdfReport, isFalse);
      expect(u.pdfReportsRemaining, 0);
    });
  });
}
