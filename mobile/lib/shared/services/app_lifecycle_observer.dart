/// AppLifecycle observer — refreshes pets + identifies the user with
/// RevenueCat/OneSignal on resume.
///
/// Phase 1D's contract: when the app comes back from background after
/// more than 5 minutes, we re-fetch pets (in case the user edited from
/// another device) and re-bind the user to RevenueCat + OneSignal so a
/// session that rotated tokens while we slept stays consistent.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pets/pets_controller.dart';
import '../providers/auth_provider.dart';
import 'logger.dart';
import 'onesignal_service.dart';
import 'revenuecat_service.dart';

class AppLifecycleObserver extends StatefulWidget {
  const AppLifecycleObserver({super.key, required this.child});
  final Widget child;

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver>
    with WidgetsBindingObserver {
  static const _idleResumeThreshold = Duration(minutes: 5);
  static final _log = AppLogger.of('app.lifecycle');

  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _pausedAt = DateTime.now();
      case AppLifecycleState.resumed:
        _maybeRefreshOnResume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _maybeRefreshOnResume() {
    final paused = _pausedAt;
    _pausedAt = null;
    if (paused == null) return;
    final idle = DateTime.now().difference(paused);
    if (idle < _idleResumeThreshold) return;
    _log.info('resume_after_idle_${idle.inMinutes}m');

    final container = ProviderScope.containerOf(context, listen: false);
    final auth = container.read(authStateProvider);
    if (auth is! Authenticated) return;

    // Refresh pets in the background.
    container.read(petsControllerProvider.notifier).refresh();
    // Re-bind to RevenueCat / OneSignal — both idempotent.
    container.read(revenueCatServiceProvider).identify(auth.user.id);
    container.read(oneSignalServiceProvider).linkUser(auth.user.id);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
