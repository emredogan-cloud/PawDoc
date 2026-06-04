import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/config/env.dart';
import 'src/notifications/onesignal_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Product analytics (Phase 1.2 onboarding events). Optional in dev/test.
  if (Env.posthogApiKey.isNotEmpty) {
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

  // Push notifications (Phase 2.1). The permission prompt is fired later, on
  // onboarding Screen 4 (contextual ask).
  OneSignalService.initialize();

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
      (options) => options.dsn = Env.sentryDsn,
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
