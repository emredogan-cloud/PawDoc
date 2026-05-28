import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/supabase_providers.dart';

class UserProfile {
  const UserProfile({
    required this.subscriptionStatus,
    required this.freeUsedThisMonth,
    this.pdfReportsRemaining = 0,
  });
  final String subscriptionStatus;
  final int freeUsedThisMonth;
  /// Phase 6.3 — credits purchased via the $4.99 pdf_report_addon. Premium
  /// tiers ignore this; the server enforces both paths.
  final int pdfReportsRemaining;

  /// Tiers that unlock all premium features. Phase 5.4 adds `b2b_lite` (sitter).
  static const _premiumTiers = {'premium', 'family', 'trial', 'b2b_lite'};

  bool get isPremium => _premiumTiers.contains(subscriptionStatus);
  int get freeRemaining => (3 - freeUsedThisMonth).clamp(0, 3);

  /// Phase 6.3 — true when the user can request a PDF Health Report without
  /// having to buy a credit first. Mirrors the server-side check in
  /// /generate-pdf-report.
  bool get canRequestPdfReport => isPremium || pdfReportsRemaining > 0;
}

/// The signed-in user's subscription + free-tier counter (RLS: own row only).
final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser!.id;
  final row = await client
      .from('users')
      .select('subscription_status, free_analyses_used_this_month, pdf_reports_remaining')
      .eq('id', uid)
      .single();
  return UserProfile(
    subscriptionStatus: (row['subscription_status'] as String?) ?? 'free',
    freeUsedThisMonth: (row['free_analyses_used_this_month'] as int?) ?? 0,
    pdfReportsRemaining: (row['pdf_reports_remaining'] as int?) ?? 0,
  );
});
