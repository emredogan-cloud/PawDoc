import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';

/// Outcome of a referral claim, mirroring the Edge Function's { ok, status,
/// message } body. `status` ∈ success | invalid_code | self_referral |
/// already_claimed | error | unauthorized.
class ReferralClaimResult {
  const ReferralClaimResult({required this.ok, required this.status, required this.message});
  final bool ok;
  final String status;
  final String message;

  bool get isFraud => status == 'self_referral' || status == 'already_claimed';
}

/// Submits a referral code to the `claim-referral` Edge Function. All fraud
/// rules + reward writes happen server-side via the RPC; the client never
/// touches the referrals table or reward columns (locked down in the DB).
class ReferralService {
  ReferralService(this._client);

  final SupabaseClient _client;

  Future<ReferralClaimResult> claim(String code) async {
    try {
      final res = await _client.functions.invoke('claim-referral', body: {'code': code.trim()});
      final data = res.data;
      if (data is Map) {
        return ReferralClaimResult(
          ok: data['ok'] == true,
          status: (data['status'] as String?) ?? 'error',
          message: (data['message'] as String?) ?? 'Something went wrong.',
        );
      }
    } catch (_) {
      // 401/503/transport -> fall through to a safe generic error.
    }
    return const ReferralClaimResult(
      ok: false,
      status: 'error',
      message: 'Could not reach the server. Please try again.',
    );
  }
}

final referralServiceProvider = Provider<ReferralService>((ref) {
  return ReferralService(ref.watch(supabaseClientProvider));
});
