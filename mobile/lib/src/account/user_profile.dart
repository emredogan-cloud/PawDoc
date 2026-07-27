import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../auth/supabase_providers.dart';
import '../config/env.dart';
import '../core/data_timeout.dart';

/// Bound on the store entitlement probe — shorter than a data read because a
/// stale `false` only means "not premium *yet*"; the webhook-written DB status
/// is the other half of the merge and still counts.
const Duration kEntitlementProbeTimeout = Duration(seconds: 6);

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

  /// Service-role-only permanent grant for PawDoc's internal QA account. A
  /// distinct status (rather than a plain `premium` row) so support, analytics
  /// and revenue reporting can tell an internal tester from a paying customer.
  /// Mirrors `supabase/functions/_shared/premium.mjs`; the client only *reads*
  /// it — `authenticated` holds no UPDATE grant on public.users, so no client
  /// can award it to itself. See docs/runbooks/INTERNAL_TEST_ACCOUNT.md.
  static const internalTesterStatus = 'internal_tester';

  /// One plan: `premium` (plus the store trial period), and the QA grant.
  static const premiumTiers = {'premium', 'trial', internalTesterStatus};

  bool get isPremium =>
      premiumTiers.contains(subscriptionStatus) || sdkEntitlementActive;
  int get photoLogsRemaining =>
      (freePhotoLogsPerMonth - photoLogsUsedThisMonth)
          .clamp(0, freePhotoLogsPerMonth);
}

/// The signed-in user's subscription + photo-log counter (RLS: own row only).
/// Merges the DB status (webhook-written) with the RevenueCat SDK entitlement
/// (device truth) so neither path alone can lock a paying user out.
final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  // Scoped to the signed-in user: watching the id makes an identity change
  // on this device recompute instead of serving the previous account's cache.
  ref.watch(currentUserIdProvider);
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser!.id;
  final row = await client
      .from('users')
      .select('subscription_status, free_analyses_used_this_month')
      .eq('id', uid)
      .single()
      .timeout(kDataReadTimeout);

  // Best-effort SDK read (SUB-02). Never throws *and never hangs*: an
  // unconfigured SDK (tests, dev builds with no key) doesn't reject — it never
  // answers, which strands this whole provider in `loading` and leaves the
  // account's subscription row inert. Device-found on a Redmi Note 11R built
  // without REVENUECAT_PUBLIC_SDK_KEY. So: only ask when main() configured it,
  // and still bound the call for a store hiccup.
  var sdkActive = false;
  if (Env.hasRevenueCat) {
    try {
      final info =
          await Purchases.getCustomerInfo().timeout(kEntitlementProbeTimeout);
      sdkActive = info.entitlements.active.isNotEmpty;
    } catch (_) {}
  }

  return UserProfile(
    subscriptionStatus: (row['subscription_status'] as String?) ?? 'free',
    photoLogsUsedThisMonth:
        (row['free_analyses_used_this_month'] as int?) ?? 0,
    sdkEntitlementActive: sdkActive,
  );
});
