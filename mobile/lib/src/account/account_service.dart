import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';

/// Account-level actions. Deletion calls the `/delete-account` Edge Function
/// (CR #9) which removes the user + cascades all their data, then signs out.
class AccountService {
  AccountService(this._client);
  final SupabaseClient _client;

  Future<void> deleteAccount() async {
    final res = await _client.functions.invoke('delete-account');
    if (res.data is Map && (res.data as Map)['ok'] == true) {
      await _client.auth.signOut();
      return;
    }
    throw Exception('Account deletion did not complete');
  }
}

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(ref.watch(supabaseClientProvider));
});
