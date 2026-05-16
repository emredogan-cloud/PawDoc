/// PawDoc mobile app — process entrypoint.
///
/// Order of operations on cold start:
///   1. WidgetsFlutterBinding.ensureInitialized
///   2. Build AppConfig from --dart-define
///   3. Validate config (throws in prod if Sentry missing)
///   4. Configure logger; emit any non-fatal warnings
///   5. Wrap the rest of the boot in Sentry (no-op when DSN empty)
///   6. Supabase.initialize
///   7. Wire FlutterError.onError into Sentry capture
///   8. runApp, then asynchronously initialise RevenueCat + OneSignal
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/services/app_lifecycle_observer.dart';
import 'shared/services/logger.dart';
import 'shared/services/onesignal_service.dart';
import 'shared/services/revenuecat_service.dart';
import 'shared/services/sentry_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final warnings = config.validate();
  AppLogger.configure(config);
  for (final w in warnings) {
    AppLogger.of('main').warning('config_warning: $w');
  }

  if (!config.hasSupabase) {
    throw StateError(
      'SUPABASE_ANON_KEY missing — pass --dart-define-from-file=env/dev.json '
      'with a populated env file (see env/dev.json.example).',
    );
  }

  await runWithSentry(config, () async {
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
      debug: !config.isProduction,
    );

    // Wire Flutter framework errors into Sentry (no-op when DSN empty).
    final priorOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      priorOnError?.call(details);
      if (!kDebugMode) {
        unawaited(sentryCapture(details.exception, details.stack));
      }
    };

    runApp(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const AppLifecycleObserver(
          child: _Bootstrapper(child: PawDocApp()),
        ),
      ),
    );
  });
}

/// Initialise RevenueCat + OneSignal at app startup. We do it inside a
/// widget rather than top-level so the providers (which need a Ref) are
/// available — without exposing the SDKs to widget code.
class _Bootstrapper extends ConsumerStatefulWidget {
  const _Bootstrapper({required this.child});
  final Widget child;
  @override
  ConsumerState<_Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends ConsumerState<_Bootstrapper> {
  ProviderSubscription<AuthStatus>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final rc = ref.read(revenueCatServiceProvider);
      await rc.initialize();
      final os = ref.read(oneSignalServiceProvider);
      await os.initialize();

      // Re-identify with RC/OneSignal on every auth state change so the
      // mobile install is consistently tied to the current user — even
      // across sign-in / sign-out cycles.
      _authSub = ref.listenManual<AuthStatus>(authStateProvider, (
        prev,
        next,
      ) async {
        if (next is Authenticated) {
          await rc.identify(next.user.id);
          await os.linkUser(next.user.id);
        } else if (next is Unauthenticated) {
          await rc.logOut();
          await os.logout();
        }
      }, fireImmediately: true);
    });
  }

  @override
  void dispose() {
    _authSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
