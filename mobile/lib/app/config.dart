/// Compile-time configuration loaded from `--dart-define-from-file`.
///
/// The contract: every value the app needs at runtime comes from a `String.fromEnvironment`
/// call. Missing values fall back to safe local defaults so a developer who
/// forgets to pass `--dart-define-from-file` still gets a usable build pointed
/// at localhost.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Logical deployment environment.
enum AppEnv {
  local,
  dev,
  prod;

  static AppEnv parse(String raw) {
    return AppEnv.values.firstWhere(
      (e) => e.name == raw.toLowerCase(),
      orElse: () => AppEnv.local,
    );
  }
}

/// Frozen configuration value-object — read once at startup, used everywhere.
class AppConfig {
  const AppConfig({
    required this.env,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.aiServiceUrl,
    required this.sentryDsn,
    required this.posthogApiKey,
    required this.posthogHost,
  });

  factory AppConfig.fromEnvironment() {
    const envRaw = String.fromEnvironment('APP_ENV', defaultValue: 'local');
    return AppConfig(
      env: AppEnv.parse(envRaw),
      supabaseUrl: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'http://127.0.0.1:54321',
      ),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      aiServiceUrl: const String.fromEnvironment(
        'AI_SERVICE_URL',
        defaultValue: 'http://10.0.2.2:8080',
      ),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
      posthogApiKey: const String.fromEnvironment('POSTHOG_API_KEY'),
      posthogHost: const String.fromEnvironment(
        'POSTHOG_HOST',
        defaultValue: 'https://eu.posthog.com',
      ),
    );
  }

  final AppEnv env;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String aiServiceUrl;
  final String sentryDsn;
  final String posthogApiKey;
  final String posthogHost;

  bool get isLocal => env == AppEnv.local;
  bool get isProduction => env == AppEnv.prod;
  bool get hasSupabase => supabaseAnonKey.isNotEmpty;
  bool get hasSentry => sentryDsn.isNotEmpty;
  bool get hasPosthog => posthogApiKey.isNotEmpty;
}

/// Riverpod provider — overridden in `main.dart`. Reading this without the
/// override is a programmer error and throws at access time.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'appConfigProvider must be overridden in ProviderScope (see main.dart).',
  );
});
