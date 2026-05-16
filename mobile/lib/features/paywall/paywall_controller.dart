/// Paywall controller — loads RevenueCat offerings, drives purchase +
/// restore.
///
/// The controller does NOT decide entitlement; the next analyze call's
/// 200/402 response from the edge function is the authoritative signal.
/// On a successful purchase we optimistically navigate the user back to
/// where they came from and let the server-side webhook propagate.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../shared/providers/auth_provider.dart';
import '../../shared/services/analytics_events.dart';
import '../../shared/services/analytics_service.dart';
import '../../shared/services/logger.dart';
import '../../shared/services/revenuecat_service.dart';

@immutable
sealed class PaywallState {
  const PaywallState();
}

class PaywallLoading extends PaywallState {
  const PaywallLoading();
}

class PaywallReady extends PaywallState {
  const PaywallReady({required this.offering, this.notice});
  final Offering offering;
  final String? notice;
}

class PaywallEmpty extends PaywallState {
  const PaywallEmpty({required this.reason});
  final String reason;
}

class PaywallPurchasing extends PaywallState {
  const PaywallPurchasing();
}

class PaywallSucceeded extends PaywallState {
  const PaywallSucceeded();
}

class PaywallFailed extends PaywallState {
  const PaywallFailed(this.kind);
  final PurchaseOutcomeKind kind;
}

class PaywallController extends StateNotifier<PaywallState> {
  PaywallController({
    required RevenueCatService rc,
    required AuthStatus auth,
    required AnalyticsService analytics,
  }) : _rc = rc,
       _auth = auth,
       _analytics = analytics,
       super(const PaywallLoading()) {
    _load();
  }

  final RevenueCatService _rc;
  final AuthStatus _auth;
  final AnalyticsService _analytics;
  static final _log = AppLogger.of('paywall.controller');

  // Convention: a single offering named `pawdoc_premium` is what we wire
  // in the RevenueCat dashboard. Family plans live in `pawdoc_family`
  // (Phase 2 wires the family-vs-premium picker; 1D ships premium only).
  static const _preferredOffering = 'pawdoc_premium';

  Future<void> _load() async {
    state = const PaywallLoading();
    if (!_rc.isEnabled) {
      _log.info('paywall_rc_disabled');
      state = const PaywallEmpty(
        reason: 'In-app purchases are not configured for this build.',
      );
      return;
    }
    final auth = _auth;
    if (auth is! Authenticated) {
      state = const PaywallEmpty(reason: 'Please sign in to subscribe.');
      return;
    }
    final userId = auth.user.id;
    // Identify the user with RevenueCat — best-effort; failures are
    // non-fatal because the SDK can still surface offerings.
    await _rc.identify(userId);

    final offerings = await _rc.getOfferings();
    if (offerings.isEmpty) {
      _log.warning('paywall_no_offerings');
      state = const PaywallEmpty(
        reason: 'No subscription plans available right now.',
      );
      return;
    }
    Offering? chosen;
    for (final o in offerings) {
      if (o.identifier == _preferredOffering) {
        chosen = o;
        break;
      }
    }
    chosen ??= offerings.first;
    if (chosen.availablePackages.isEmpty) {
      state = const PaywallEmpty(reason: 'Plans temporarily unavailable.');
      return;
    }
    state = PaywallReady(offering: chosen);
    unawaited(
      _analytics.track(PaywallSeenEvent(offeringId: chosen.identifier)),
    );
  }

  Future<void> purchase(Package package) async {
    if (state is PaywallPurchasing) return;
    state = const PaywallPurchasing();
    final outcome = await _rc.purchase(package);
    _log.info('paywall_purchase_outcome', outcome.kind.name);
    switch (outcome.kind) {
      case PurchaseOutcomeKind.success:
        state = const PaywallSucceeded();
        unawaited(
          _analytics.track(
            SubscriptionStartedEvent(packageId: package.identifier),
          ),
        );
      case PurchaseOutcomeKind.userCancelled:
        // Restore to ready state; user just stepped back.
        await _load();
      default:
        state = PaywallFailed(outcome.kind);
    }
  }

  Future<void> restore() async {
    state = const PaywallPurchasing();
    final outcome = await _rc.restore();
    if (outcome.kind == PurchaseOutcomeKind.success) {
      state = const PaywallSucceeded();
      unawaited(_analytics.track(const RestorePurchaseEvent()));
    } else {
      state = PaywallFailed(outcome.kind);
      await Future<void>.delayed(const Duration(seconds: 1));
      await _load();
    }
  }

  Future<void> refresh() => _load();
}

final paywallControllerProvider =
    StateNotifierProvider.autoDispose<PaywallController, PaywallState>(
      (ref) => PaywallController(
        rc: ref.watch(revenueCatServiceProvider),
        auth: ref.watch(authStateProvider),
        analytics: ref.watch(analyticsServiceProvider),
      ),
    );
