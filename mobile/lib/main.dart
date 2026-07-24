import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/config/env.dart';
import 'src/core/consent_prefs.dart';
import 'src/notifications/local_notifications.dart';
import 'src/core/boot_error_app.dart';
import 'src/theme/design_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch uncaught ASYNC errors. supabase_flutter's background session
  // auto-refresh throws AuthRetryableFetchException (SocketException / failed
  // host lookup) on every ~20s tick while the network is unreachable; without
  // a handler these spam the log as "Unhandled Exception" and would flood
  // Sentry. Transient network/auth-retry errors are expected — swallow them;
  // report anything else so real bugs still surface.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    final s = error.toString();
    final transient = error is AuthRetryableFetchException ||
        s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('ClientException') ||
        s.contains('TimeoutException');
    if (!transient) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pawdoc (uncaught async)',
      ));
    }
    return true; // handled — never crash to the default reporter
  };

  // ENG-01: brand fonts are BUNDLED (assets/google_fonts/) — never fetched
  // over the network. First launch renders correct type offline, and no
  // pre-consent request to fonts.gstatic.com ever fires.
  GoogleFonts.config.allowRuntimeFetching = false;

  // On-device reminder notifications (H2 — no push vendor). Init only; the
  // permission ask is contextual at first reminder creation.
  await LocalNotifications.instance.initialize();

  // In release, replace Flutter's raw red error box for any in-tree build/render
  // failure with a calm placeholder — a user must never see a stack trace. Debug
  // keeps the red screen (useful for developers; tests run in debug too).
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const _CalmInlineError();
  }

  // Top-level boundary: if initialization throws before the UI can mount (e.g.
  // Supabase init fails), show a calm "Couldn't start — retry" screen instead of
  // crashing into a raw stack trace (closes runtime R09).
  await _bootstrap();
}

Future<void> _bootstrap() async {
  try {
    await _initAndRun();
  } catch (e, st) {
    // Route through the framework so a configured Sentry still captures it.
    FlutterError.reportError(FlutterErrorDetails(
      exception: e,
      stack: st,
      library: 'pawdoc bootstrap',
    ));
    runApp(BootErrorApp(onRetry: _bootstrap));
  }
}

Future<void> _initAndRun() async {
  // Supabase is required at runtime. Built without the SUPABASE_URL /
  // SUPABASE_ANON_KEY dart-defines, init is skipped and the app shows a clear
  // configuration-required screen (see startApp) instead of crashing into a
  // raw provider/assertion error screen. Real builds inject these via
  // --dart-define (CI / Doppler), so production users never hit this path.
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  // Product analytics — CONSENT-GATED (evolution I2): the privacy policy
  // names consent as the legal basis, so PostHog initializes only after the
  // user opted in (signup checkbox / Account toggle). No consent, no SDK.
  if (Env.posthogApiKey.isNotEmpty && await ConsentPrefs.analyticsEnabled()) {
    final config = PostHogConfig(Env.posthogApiKey)..host = Env.posthogHost;
    await Posthog().setup(config);
    // Deterministic, stable A/B bucketing (Phase 4.1): tie PostHog's distinct_id
    // to the Supabase uid so a user always lands in the same variant.
    if (Env.hasSupabase) {
      Supabase.instance.client.auth.onAuthStateChange.listen((state) async {
        final uid = state.session?.user.id;
        if (uid != null) {
          try {
            await Posthog().identify(userId: uid);
          } catch (_) {}
        }
      });
    }
  }

  // RevenueCat (Phase 1.4 paywall). Optional in dev/test. The app_user_id is
  // tied to the Supabase user so /revenuecat-webhook updates the right row.
  if (Env.revenueCatPublicKey.isNotEmpty) {
    try {
      await Purchases.configure(PurchasesConfiguration(Env.revenueCatPublicKey));
      if (Env.hasSupabase) {
        Supabase.instance.client.auth.onAuthStateChange.listen((state) async {
          final uid = state.session?.user.id;
          if (uid != null) {
            try {
              await Purchases.logIn(uid);
            } catch (_) {}
          }
        });
      }
    } catch (_) {}
  }

  // GAP-E6: on sign-out, dissociate this device from the user's external
  // identities (push, purchases, analytics) so nothing bleeds into the next
  // account signed in on the same device. Best-effort: each call is guarded.
  if (Env.hasSupabase) {
    Supabase.instance.client.auth.onAuthStateChange.listen((state) async {
      if (state.event != AuthChangeEvent.signedOut) return;
      try {
        await Purchases.logOut();
      } catch (_) {}
      try {
        await Posthog().reset();
      } catch (_) {}
    });
  }

  // Without Supabase configured the Supabase-backed providers (router, auth)
  // cannot be built and would surface a raw provider/assertion error screen
  // (Supabase.instance not initialized). Show an explicit configuration screen
  // instead: still refuses to run misconfigured (no fake backend), but fails
  // cleanly. Found + fixed during on-device validation (2026-06-04).
  void startApp() {
    if (!Env.hasSupabase) {
      runApp(const _MissingConfigApp());
      return;
    }
    runApp(const ProviderScope(child: PawDocApp()));
  }

  // Initialize Sentry early to capture dev-time crashes (Phase 1.1 deliverable).
  if (Env.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = Env.sentryDsn;
        // GAP-D2: tag every event with environment + release so prod issues are
        // filterable and regressions are attributable to a specific build.
        options.environment = kReleaseMode ? 'prod' : 'dev';
        // Crash reports carry no default PII (matches the AI service's
        // send_default_pii=False + the privacy policy's disclosure).
        options.sendDefaultPii = false;
        options.release =
            'pawdoc@${const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1')}';
      },
      appRunner: startApp,
    );
  } else {
    startApp();
  }
}

/// Shown only when the app was built without SUPABASE_URL / SUPABASE_ANON_KEY
/// (no backend). Production / CI builds always inject these via --dart-define,
/// so users never see this. It replaces the raw provider-error screen that would
/// otherwise appear because the Supabase-backed providers cannot initialize.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings_suggest_outlined, size: 48),
                SizedBox(height: 16),
                Text(
                  'PawDoc is not configured',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'This build is missing SUPABASE_URL and SUPABASE_ANON_KEY. '
                  'Rebuild with --dart-define values (from Doppler) to connect '
                  'to the backend.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Calm in-place replacement for Flutter's red error box (release only). Used
/// for in-tree build/render failures so a user never sees a raw stack trace.
/// Self-contained (provides its own Directionality) because it can be inserted
/// anywhere in the tree, including before MaterialApp mounts.
class _CalmInlineError extends StatelessWidget {
  const _CalmInlineError();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: AppColors.ink900,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets_rounded, color: AppColors.ink300, size: 40),
            const SizedBox(height: AppSpace.s12),
            Text(
              'Something went wrong on this screen.',
              textAlign: TextAlign.center,
              style: AppType.textTheme().bodyLarge?.copyWith(color: AppColors.ink50),
            ),
          ],
        ),
      ),
    );
  }
}
