import 'package:purchases_flutter/purchases_flutter.dart';

/// User-facing copy for a purchase that did not complete.
///
/// Found on-device 2026-07-27: the paywall rendered the raw `PlatformException`
/// in a snackbar — fifteen lines of `readableErrorCode`, `DebugMessage`,
/// `SubResponseCode: NO_APPLICABLE_SUB_RESPONSE_CODE` — to an ordinary user
/// trying to subscribe. Store/SDK internals are never shown; each case gets a
/// sentence that says what happened and what to do next.
///
/// Returns **null** when nothing should be shown at all. Backing out of the
/// Play sheet is a decision, not a failure, and must not raise an error toast.
String? purchaseErrorMessage(PurchasesErrorCode code) {
  switch (code) {
    // Not an error — the user chose not to buy.
    case PurchasesErrorCode.purchaseCancelledError:
      return null;

    // Play's deferred/pending payment (slow bank, cash payment). The purchase
    // may still succeed later, so this must not read as a failure.
    case PurchasesErrorCode.paymentPendingError:
      return 'Your payment is still being confirmed. Premium unlocks '
          'automatically once your payment method goes through.';

    case PurchasesErrorCode.productAlreadyPurchasedError:
      return 'You already have this subscription. Tap "Restore purchases" to '
          'unlock Premium on this account.';

    case PurchasesErrorCode.receiptAlreadyInUseError:
    case PurchasesErrorCode.receiptInUseByOtherSubscriberError:
      return 'This store subscription is already linked to a different PawDoc '
          'account. Sign in with that account, or contact support.';

    case PurchasesErrorCode.networkError:
      return 'Could not reach the store. Check your connection and try again.';

    case PurchasesErrorCode.storeProblemError:
    case PurchasesErrorCode.unknownBackendError:
    case PurchasesErrorCode.unexpectedBackendResponseError:
      return 'The store is having trouble right now. Please try again in a '
          'few minutes — you have not been charged.';

    case PurchasesErrorCode.purchaseNotAllowedError:
    case PurchasesErrorCode.insufficientPermissionsError:
      return 'This device or Google account is not allowed to make purchases. '
          'Check your Google Play account settings and try again.';

    case PurchasesErrorCode.productNotAvailableForPurchaseError:
    case PurchasesErrorCode.ineligibleError:
      return 'That plan is not available for your account right now.';

    // DEVELOPER_ERROR / misconfiguration. The single most likely cause in the
    // field is a build installed outside Google Play, which cannot transact.
    case PurchasesErrorCode.purchaseInvalidError:
    case PurchasesErrorCode.configurationError:
    case PurchasesErrorCode.invalidCredentialsError:
    case PurchasesErrorCode.invalidAppUserIdError:
      return 'Purchases are not available in this copy of PawDoc. If you '
          'installed it outside Google Play, install it from Play and try again.';

    case PurchasesErrorCode.operationAlreadyInProgressError:
      return 'A purchase is already in progress. Give it a moment.';

    default:
      return 'The purchase did not complete. Please try again — you have not '
          'been charged.';
  }
}

/// Shown when the store reports success but hands back no active entitlement
/// (for example a deferred purchase). Previously this path was silent, leaving
/// the user staring at an unchanged paywall with no idea what happened.
const String purchaseNoEntitlementMessage =
    'The store did not report an active subscription yet. If you were charged, '
    'tap "Restore purchases" in a moment.';
