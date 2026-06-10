import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';

/// Worst case (invoke timeout + auth probe) must stay inside the 15-second
/// budget from the M0 acceptance criteria (live bug F-1).
const kDeleteAccountTimeout = Duration(seconds: 10);
const kDeleteProbeTimeout = Duration(seconds: 4);

/// Account-level actions. Deletion calls the `/delete-account` Edge Function
/// (CR #9) which removes the user + cascades all their data, then signs out.
class AccountService {
  AccountService(this._client);
  final SupabaseClient _client;

  /// Live bug F-1: the server cascade can complete (revoking this session)
  /// while the function response is lost — the old code then hung forever in
  /// "Deleting…". Now: the call is time-boxed, and on timeout/auth-shaped
  /// failures we probe whether our credentials still work. Credentials gone
  /// means the account is gone — that is a success, not an error.
  Future<void> deleteAccount() async {
    try {
      final res = await _client.functions
          .invoke('delete-account')
          .timeout(kDeleteAccountTimeout);
      if (res.data is! Map || (res.data as Map)['ok'] != true) {
        throw Exception('Account deletion did not complete');
      }
    } on TimeoutException {
      if (!await _authRevoked()) rethrow;
    } on FunctionException {
      if (!await _authRevoked()) rethrow;
    } on AuthException {
      if (!await _authRevoked()) rethrow;
    }
    await _signOutLocal();
  }

  /// True when our session no longer works against the auth server — i.e. the
  /// deletion cascade revoked it. Conservative: probe failures that aren't a
  /// definite auth rejection return false, so a real error still surfaces.
  Future<bool> _authRevoked() async {
    if (_client.auth.currentSession == null) return true;
    try {
      await _client.auth.getUser().timeout(kDeleteProbeTimeout);
      return false;
    } on AuthException {
      return true;
    } on TimeoutException {
      return false;
    }
  }

  /// Clear the local session; the auth-state listener then routes to /sign-in.
  /// Local scope only — the server side is already gone after deletion, and a
  /// global sign-out call against a revoked session can itself hang or 401.
  Future<void> _signOutLocal() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Best-effort: a revoked server session may reject the call; the local
      // session is cleared regardless and signed-out is the desired end state.
    }
  }
}

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(ref.watch(supabaseClientProvider));
});
