/// PawDoc mobile app — process entrypoint.
///
/// Single entrypoint for both dev and prod builds. Environment is selected at
/// compile time via `--dart-define-from-file=env/dev.json` (or `env/prod.json`),
/// **not** at runtime by reading a `.env`. This means:
///   - the resulting binary contains the env's identity (no runtime selection)
///   - secrets that aren't safe to ship in a binary (e.g. service-role keys)
///     are NEVER in `env/*.json` — those live server-side only
///
/// Run locally:
///   flutter run --dart-define-from-file=env/dev.json
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'shared/services/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  AppLogger.configure(config);

  // Run the app inside a ProviderScope so every widget below has access to the
  // Riverpod tree. The config is exposed as an override so feature code can
  // depend on `appConfigProvider` instead of importing this file.
  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const PawDocApp(),
    ),
  );
}
