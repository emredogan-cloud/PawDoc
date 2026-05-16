/// RevenueCat integration — purchase + restore + entitlement read.
///
/// Discipline:
/// - The server (`public.users.subscription_status` driven by the
///   `revenuecat-webhook`) is the source of truth for gating. This
///   service exists to:
///     * present available packages on the paywall,
///     * trigger the SDK's purchase / restore flows,
///     * report success/failure to the UI.
///   It does NOT decide whether the user is entitled — the next analyze
///   call asks the server.
/// - All SDK methods are wrapped to no-op gracefully when no public key
///   is configured. Local development builds skip RevenueCat entirely.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../app/config.dart';
import 'logger.dart';

enum PurchaseOutcomeKind {
  success,
  userCancelled,
  paymentPending,
  notSupported,
  alreadyEntitled,
  invalidReceipt,
  network,
  unknown;

  String get userMessage => switch (this) {
    PurchaseOutcomeKind.success => '',
    PurchaseOutcomeKind.userCancelled => '',
    PurchaseOutcomeKind.paymentPending =>
      'Your purchase is pending. Try again in a minute.',
    PurchaseOutcomeKind.notSupported =>
      'In-app purchases are not available on this device.',
    PurchaseOutcomeKind.alreadyEntitled =>
      "You're already subscribed — tap Restore to refresh.",
    PurchaseOutcomeKind.invalidReceipt =>
      "We couldn't verify that purchase. Contact support if charged.",
    PurchaseOutcomeKind.network =>
      'No internet connection. Reconnect and try again.',
    PurchaseOutcomeKind.unknown =>
      'Something went wrong. Try again or contact support.',
  };
}

@immutable
class PurchaseOutcome {
  const PurchaseOutcome(this.kind);
  final PurchaseOutcomeKind kind;
  bool get success => kind == PurchaseOutcomeKind.success;
}

abstract class RevenueCatService {
  bool get isEnabled;

  Future<void> initialize();

  Future<void> identify(String userId);

  Future<List<Offering>> getOfferings();

  Future<PurchaseOutcome> purchase(Package package);

  Future<PurchaseOutcome> restore();

  Future<void> logOut();
}

class RevenueCatServiceImpl implements RevenueCatService {
  RevenueCatServiceImpl({required this.publicKey});

  final String publicKey;
  bool _initialized = false;
  static final _log = AppLogger.of('purchases.revenuecat');

  @override
  bool get isEnabled => publicKey.isNotEmpty && _initialized;

  @override
  Future<void> initialize() async {
    if (_initialized || publicKey.isEmpty) {
      _log.info(
        'revenuecat_skip',
        publicKey.isEmpty ? 'no_public_key' : 'already_initialized',
      );
      return;
    }
    try {
      await Purchases.configure(PurchasesConfiguration(publicKey));
      _initialized = true;
      _log.info('revenuecat_initialized');
    } on PlatformException catch (e) {
      _log.warning('revenuecat_init_failed', e.message);
    } on Object catch (e, s) {
      _log.severe('revenuecat_init_unexpected', e, s);
    }
  }

  @override
  Future<void> identify(String userId) async {
    if (!isEnabled) return;
    try {
      await Purchases.logIn(userId);
      _log.info('revenuecat_identified');
    } on PlatformException catch (e) {
      _log.warning('revenuecat_identify_failed', e.message);
    }
  }

  @override
  Future<List<Offering>> getOfferings() async {
    if (!isEnabled) return const [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.all.values.toList(growable: false);
    } on PlatformException catch (e) {
      _log.warning('revenuecat_offerings_failed', e.message);
      return const [];
    }
  }

  @override
  Future<PurchaseOutcome> purchase(Package package) async {
    if (!isEnabled) {
      return const PurchaseOutcome(PurchaseOutcomeKind.notSupported);
    }
    try {
      await Purchases.purchasePackage(package);
      _log.info('revenuecat_purchase_complete');
      return const PurchaseOutcome(PurchaseOutcomeKind.success);
    } on PlatformException catch (e) {
      return PurchaseOutcome(_mapException(e));
    } on Object catch (e, s) {
      _log.severe('revenuecat_purchase_unexpected', e, s);
      return const PurchaseOutcome(PurchaseOutcomeKind.unknown);
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    if (!isEnabled) {
      return const PurchaseOutcome(PurchaseOutcomeKind.notSupported);
    }
    try {
      final info = await Purchases.restorePurchases();
      final hasEntitlement = info.entitlements.active.isNotEmpty;
      _log.info('revenuecat_restore_complete', hasEntitlement);
      return PurchaseOutcome(
        hasEntitlement
            ? PurchaseOutcomeKind.success
            : PurchaseOutcomeKind.unknown,
      );
    } on PlatformException catch (e) {
      return PurchaseOutcome(_mapException(e));
    } on Object catch (e, s) {
      _log.severe('revenuecat_restore_unexpected', e, s);
      return const PurchaseOutcome(PurchaseOutcomeKind.unknown);
    }
  }

  @override
  Future<void> logOut() async {
    if (!isEnabled) return;
    try {
      await Purchases.logOut();
    } on PlatformException catch (e) {
      _log.warning('revenuecat_logout_failed', e.message);
    }
  }

  PurchaseOutcomeKind _mapException(PlatformException e) {
    final code = PurchasesErrorHelper.getErrorCode(e);
    return switch (code) {
      PurchasesErrorCode.purchaseCancelledError =>
        PurchaseOutcomeKind.userCancelled,
      PurchasesErrorCode.paymentPendingError =>
        PurchaseOutcomeKind.paymentPending,
      PurchasesErrorCode.purchaseNotAllowedError ||
      PurchasesErrorCode.purchaseInvalidError ||
      PurchasesErrorCode.productNotAvailableForPurchaseError ||
      PurchasesErrorCode.storeProblemError => PurchaseOutcomeKind.notSupported,
      PurchasesErrorCode.networkError => PurchaseOutcomeKind.network,
      PurchasesErrorCode.productAlreadyPurchasedError =>
        PurchaseOutcomeKind.alreadyEntitled,
      PurchasesErrorCode.invalidReceiptError ||
      PurchasesErrorCode.receiptInUseByOtherSubscriberError =>
        PurchaseOutcomeKind.invalidReceipt,
      _ => PurchaseOutcomeKind.unknown,
    };
  }
}

class NoopRevenueCatService implements RevenueCatService {
  const NoopRevenueCatService();
  @override
  bool get isEnabled => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> identify(String userId) async {}
  @override
  Future<List<Offering>> getOfferings() async => const [];
  @override
  Future<PurchaseOutcome> purchase(Package package) async =>
      const PurchaseOutcome(PurchaseOutcomeKind.notSupported);
  @override
  Future<PurchaseOutcome> restore() async =>
      const PurchaseOutcome(PurchaseOutcomeKind.notSupported);
  @override
  Future<void> logOut() async {}
}

final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  final config = ref.watch(appConfigProvider);
  final key = Platform.isIOS
      ? config.revenueCatPublicKeyIos
      : config.revenueCatPublicKeyAndroid;
  if (key.isEmpty) return const NoopRevenueCatService();
  return RevenueCatServiceImpl(publicKey: key);
});
