import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../auth/supabase_providers.dart';

class UserProfile {
  const UserProfile({
    required this.subscriptionStatus,
    required this.photoLogsUsedThisMonth,
    this.sdkEntitlementActive = false,
  });
  final String subscriptionStatus;

  /// Quota v3: the meter is PHOTO LOGS only (5/month free). Text guidance is
  /// unmetered — safety is never counted.
  final int photoLogsUsedThisMonth;

  /// SUB-02: true when the RevenueCat SDK reports an active entitlement on
  /// this device. Premium recognition no longer depends 100% on the webhook —
  /// a paid user is premium the moment the store confirms, even if the
  /// webhook is delayed or misconfigured.
  final bool sdkEntitlementActive;

  static const freePhotoLogsPerMonth = 5;

  /// One plan: `premium` (plus the store trial period).
  static const _premiumTiers = {'premium', 'trial'};

  bool get isPremium =>
      _premiumTiers.contains(subscriptionStatus) || sdkEntitlementActive;
  int get photoLogsRemaining =>
      (freePhotoLogsPerMonth - photoLogsUsedThisMonth)
          .clamp(0, freePhotoLogsPerMonth);
}

/// The signed-in user's subscription + photo-log counter (RLS: own row only).
/// Merges the DB status (webhook-written) with the RevenueCat SDK entitlement
/// (device truth) so neither path alone can lock a paying user out.
final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser!.id;
  final row = await client
      .from('users')
      .select('subscription_status, free_analyses_used_this_month')
      .eq('id', uid)
      .single();

  // Best-effort SDK read (SUB-02). Never throws: unconfigured SDK (tests,
  // dev builds without a key) or a store hiccup simply yields false.
  var sdkActive = false;
  try {
    final info = await Purchases.getCustomerInfo();
    sdkActive = info.entitlements.active.isNotEmpty;
  } catch (_) {}

  return UserProfile(
    subscriptionStatus: (row['subscription_status'] as String?) ?? 'free',
    photoLogsUsedThisMonth:
        (row['free_analyses_used_this_month'] as int?) ?? 0,
    sdkEntitlementActive: sdkActive,
  );
});
