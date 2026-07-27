import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:pawdoc/src/monetization/purchase_error_message.dart';

/// Regression cover for the raw-exception leak found on-device 2026-07-27.
///
/// Tapping a plan on a side-loaded build put the entire PlatformException in a
/// snackbar: "PlatformException(4, One or more of the arguments provided are
/// invalid., {code: 4, ... readableErrorCode: PurchaseInvalidError, ...
/// DebugMessage: Please ensure the specific App version has been published..,
/// ErrorCode: DEVELOPER_ERROR. SubResponseCode: NO_APPLICABLE_SUB_RESPONSE_CODE.,
/// userCancelled: false}, null)".
void main() {
  group('purchaseErrorMessage', () {
    test('says nothing when the user cancelled — cancelling is not an error', () {
      expect(
        purchaseErrorMessage(PurchasesErrorCode.purchaseCancelledError),
        isNull,
      );
    });

    test('treats a pending payment as pending, not as a failure', () {
      final msg = purchaseErrorMessage(PurchasesErrorCode.paymentPendingError)!;
      expect(msg, contains('confirmed'));
      expect(msg.toLowerCase(), isNot(contains('failed')));
    });

    test('points an already-purchased user at Restore', () {
      expect(
        purchaseErrorMessage(PurchasesErrorCode.productAlreadyPurchasedError),
        contains('Restore purchases'),
      );
    });

    test('explains the sideload case for DEVELOPER_ERROR', () {
      // This is exactly the code Play returned on the unpublished build.
      expect(
        purchaseErrorMessage(PurchasesErrorCode.purchaseInvalidError),
        contains('Google Play'),
      );
    });

    test('reassures about billing when the store is at fault', () {
      expect(
        purchaseErrorMessage(PurchasesErrorCode.storeProblemError),
        contains('not been charged'),
      );
    });

    test('has a message for a network failure', () {
      expect(
        purchaseErrorMessage(PurchasesErrorCode.networkError),
        contains('connection'),
      );
    });

    test('every non-cancel code yields human copy with no SDK internals', () {
      const leaks = [
        'PlatformException',
        'readableErrorCode',
        'DebugMessage',
        'SubResponseCode',
        'ErrorCode:',
        'NO_APPLICABLE',
        'DEVELOPER_ERROR',
        'userCancelled',
        'null',
        '{',
        '}',
      ];
      for (final code in PurchasesErrorCode.values) {
        final msg = purchaseErrorMessage(code);
        if (code == PurchasesErrorCode.purchaseCancelledError) {
          expect(msg, isNull, reason: 'cancel must stay silent');
          continue;
        }
        expect(msg, isNotNull, reason: '$code produced no message');
        expect(msg!.trim(), isNotEmpty, reason: '$code produced empty copy');
        for (final leak in leaks) {
          expect(msg, isNot(contains(leak)),
              reason: '$code leaks "$leak" to the user');
        }
        // Human copy ends in a sentence, not a stack frame.
        expect(msg.endsWith('.'), isTrue, reason: '$code: "$msg"');
      }
    });
  });

  test('the no-entitlement fallback tells the user what to do next', () {
    expect(purchaseNoEntitlementMessage, contains('Restore purchases'));
    expect(purchaseNoEntitlementMessage, isNot(contains('PlatformException')));
  });
}
