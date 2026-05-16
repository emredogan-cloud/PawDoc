/// OneSignal push-notification foundation.
///
/// Phase 1D scope (per `phase1d-production-plan.md` §5):
///   - SDK initialised when `ONESIGNAL_APP_ID` is configured.
///   - `OneSignal.login(userId)` ties the device-level player id to a
///     PawDoc user across reinstalls.
///   - The player id is persisted to `public.users.one_signal_player_id`
///     via a service-role-bypass on `users.UPDATE` (uses
///     `service-role`-style RPC — Phase 1D doesn't add a new RPC; we go
///     through the supabase functions invoke pattern in 1E).
///
/// For 1D we accept the simpler write: the column has a column-level
/// GRANT in Phase 1A which allows `authenticated` to set
/// `one_signal_player_id`. So a plain `update().eq('id', userId)` works
/// under the user's JWT.
///
/// Out of scope: campaigns, reminder schedules, in-app messaging.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../app/config.dart';
import 'logger.dart';
import 'supabase_client.dart';

abstract class OneSignalService {
  /// Initialise the SDK (no-op if [appId] is empty). Safe to call multiple
  /// times.
  Future<void> initialize();

  /// Bind the local install to a PawDoc user. Idempotent — safe to call
  /// after every successful sign-in.
  Future<void> linkUser(String userId);

  /// Prompt for notification permission. Returns the user's response.
  Future<bool> requestPermission();

  /// Disable push for the current user (called on sign-out).
  Future<void> logout();

  /// True once the SDK initialised and we have an app id.
  bool get isEnabled;
}

class OneSignalServiceImpl implements OneSignalService {
  OneSignalServiceImpl({required this.appId, required this.client});

  final String appId;
  final SupabaseClient client;

  bool _initialized = false;
  static final _log = AppLogger.of('push.onesignal');

  @override
  bool get isEnabled => appId.isNotEmpty && _initialized;

  @override
  Future<void> initialize() async {
    if (_initialized || appId.isEmpty) {
      _log.info(
        'onesignal_skip',
        appId.isEmpty ? 'no_app_id' : 'already_initialized',
      );
      return;
    }
    try {
      // OneSignal's initialize() is fire-and-forget in the Flutter SDK;
      // we don't have a meaningful Future to await on.
      //
      // IMPORTANT (App Store privacy): OneSignal v5+ defaults to NOT
      // accessing IDFA. We deliberately do NOT call any of the SDK's
      // IDFA-enabling helpers (OneSignal.setRequiresPrivacyConsent or
      // an explicit IDFA opt-in). Because of this:
      //   - We do NOT add NSUserTrackingUsageDescription to Info.plist
      //   - We do NOT call AppTrackingTransparency.requestTrackingAuth
      //   - Our PrivacyInfo.xcprivacy declares NSPrivacyTracking = false
      // See docs/reports/sprint-a1-compliance-plan.md §4 for the
      // full audit. If the SDK is upgraded, re-verify this contract.
      // ignore: unawaited_futures
      OneSignal.initialize(appId);
      _initialized = true;
      _log.info('onesignal_initialized');
    } on Object catch (e, s) {
      _log.severe('onesignal_init_failed', e, s);
    }
  }

  @override
  Future<void> linkUser(String userId) async {
    if (!isEnabled) return;
    try {
      await OneSignal.login(userId);
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId == null || playerId.isEmpty) {
        _log.info('onesignal_link_pending_player_id');
        return;
      }
      await _persistPlayerId(userId, playerId);
    } on Object catch (e, s) {
      _log.warning('onesignal_link_failed', e);
      // Non-fatal; we don't want to block sign-in on push registration.
      if (kDebugMode) _log.severe('onesignal_link_unexpected', e, s);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!isEnabled) return false;
    try {
      return await OneSignal.Notifications.requestPermission(false);
    } on Object catch (e) {
      _log.warning('onesignal_permission_failed', e);
      return false;
    }
  }

  @override
  Future<void> logout() async {
    if (!isEnabled) return;
    try {
      await OneSignal.logout();
    } on Object catch (e) {
      _log.warning('onesignal_logout_failed', e);
    }
  }

  Future<void> _persistPlayerId(String userId, String playerId) async {
    try {
      await client
          .from('users')
          .update({'one_signal_player_id': playerId})
          .eq('id', userId);
      _log.info('onesignal_player_id_persisted');
    } on PostgrestException catch (e) {
      _log.warning('onesignal_persist_failed', '${e.code} ${e.message}');
    }
  }
}

class NoopOneSignalService implements OneSignalService {
  const NoopOneSignalService();
  @override
  bool get isEnabled => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> linkUser(String userId) async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> logout() async {}
}

final oneSignalServiceProvider = Provider<OneSignalService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasOneSignal) {
    return const NoopOneSignalService();
  }
  return OneSignalServiceImpl(
    appId: config.oneSignalAppId,
    client: ref.watch(supabaseClientProvider),
  );
});
