import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/referral/referral_screen.dart';
import 'package:pawdoc/src/referral/referral_service.dart';

void main() {
  group('referralCodeFromUid', () {
    test('first 8 hex chars, uppercased, hyphens stripped', () {
      expect(referralCodeFromUid('1a2b3c4d-5e6f-7890-abcd-ef0123456789'), '1A2B3C4D');
    });

    test('empty uid falls back to PAWDOC', () {
      expect(referralCodeFromUid(''), 'PAWDOC');
    });

    test('short uid does not overflow', () {
      expect(referralCodeFromUid('abc'), 'ABC');
    });
  });

  group('ReferralClaimResult.isFraud', () {
    test('flags self_referral and already_claimed only', () {
      expect(const ReferralClaimResult(ok: false, status: 'self_referral', message: '').isFraud, isTrue);
      expect(const ReferralClaimResult(ok: false, status: 'already_claimed', message: '').isFraud, isTrue);
      expect(const ReferralClaimResult(ok: true, status: 'success', message: '').isFraud, isFalse);
      expect(const ReferralClaimResult(ok: false, status: 'invalid_code', message: '').isFraud, isFalse);
    });
  });
}
