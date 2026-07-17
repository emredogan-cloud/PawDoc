import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/supabase_providers.dart';

class UserProfile {
  const UserProfile({
    required this.subscriptionStatus,
    required this.freeUsedThisMonth,
  });
  final String subscriptionStatus;
  final int freeUsedThisMonth;

  /// Tiers that unlock all premium features. One plan: `premium` (plus the
  /// store trial period). PDF reports are premium-included — no credit packs.
  static const _premiumTiers = {'premium', 'trial'};

  bool get isPremium => _premiumTiers.contains(subscriptionStatus);
  int get freeRemaining => (3 - freeUsedThisMonth).clamp(0, 3);
}

/// The signed-in user's subscription + free-tier counter (RLS: own row only).
final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser!.id;
  final row = await client
      .from('users')
      .select('subscription_status, free_analyses_used_this_month')
      .eq('id', uid)
      .single();
  return UserProfile(
    subscriptionStatus: (row['subscription_status'] as String?) ?? 'free',
    freeUsedThisMonth: (row['free_analyses_used_this_month'] as int?) ?? 0,
  );
});
