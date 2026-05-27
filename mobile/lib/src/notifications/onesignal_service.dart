import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../auth/supabase_providers.dart';
import '../config/env.dart';

/// OneSignal push. Initialized in main(); the permission request is fired from
/// Onboarding Screen 4. On grant, the player/subscription id is synced to
/// `users.one_signal_player_id`.
class OneSignalService {
  OneSignalService(this._ref);
  final Ref _ref;

  static void initialize() {
    if (Env.oneSignalAppId.isEmpty) return;
    OneSignal.initialize(Env.oneSignalAppId);
  }

  /// Request push permission (the contextual prompt on Screen 4) and sync the id.
  Future<bool> requestPermissionAndSync() async {
    if (Env.oneSignalAppId.isEmpty) return false;
    try {
      final client = _ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        await OneSignal.login(uid); // tie the OneSignal external id to the user
      }
      final granted = await OneSignal.Notifications.requestPermission(true);
      final playerId = OneSignal.User.pushSubscription.id;
      if (granted && playerId != null && uid != null) {
        await client.from('users').update({'one_signal_player_id': playerId}).eq('id', uid);
      }
      return granted;
    } catch (_) {
      return false; // push is non-critical; never block onboarding
    }
  }
}

final oneSignalServiceProvider = Provider<OneSignalService>((ref) => OneSignalService(ref));
