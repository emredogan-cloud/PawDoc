/// PawDoc mobile app — process entrypoint.
///
/// Single entrypoint for both dev and prod builds. Environment is selected
/// at compile time via `--dart-define-from-file=env/dev.json` (or
/// `env/prod.json`), **not** at runtime by reading a `.env`.
///
/// Run locally:
///   flutter run --dart-define-from-file=env/dev.json
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'shared/services/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  AppLogger.configure(config);

  if (!config.hasSupabase) {
    throw StateError(
      'SUPABASE_ANON_KEY missing — pass --dart-define-from-file=env/dev.json '
      'with a populated env file (see env/dev.json.example).',
    );
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
    // Use the default SecureStorage for refresh tokens on iOS/Android.
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
    debug: !config.isProduction,
  );

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const PawDocApp(),
    ),
  );
}
