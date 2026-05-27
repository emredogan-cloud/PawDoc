import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase is required at runtime; guarded so the app still launches in a
  // dev/test build without --dart-define (it will route to sign-in and any
  // backend call will surface a clear error).
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
  }

  void startApp() => runApp(const ProviderScope(child: PawDocApp()));

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
