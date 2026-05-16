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
    this.revenueCatPublicKeyIos = '',
    this.revenueCatPublicKeyAndroid = '',
    this.oneSignalAppId = '',
    this.appleSignInEnabled = false,
    this.tosUrl = 'https://pawdoc.app/terms',
    this.privacyUrl = 'https://pawdoc.app/privacy',
    this.appVersion = '0.1.0',
    this.buildNumber = 'local',
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
      revenueCatPublicKeyIos: const String.fromEnvironment(
        'REVENUECAT_PUBLIC_KEY_IOS',
      ),
      revenueCatPublicKeyAndroid: const String.fromEnvironment(
        'REVENUECAT_PUBLIC_KEY_ANDROID',
      ),
      oneSignalAppId: const String.fromEnvironment('ONESIGNAL_APP_ID'),
      appleSignInEnabled: const bool.fromEnvironment(
        'APPLE_SIGN_IN_ENABLED',
        defaultValue: false,
      ),
      tosUrl: const String.fromEnvironment(
        'TOS_URL',
        defaultValue: 'https://pawdoc.app/terms',
      ),
      privacyUrl: const String.fromEnvironment(
        'PRIVACY_URL',
        defaultValue: 'https://pawdoc.app/privacy',
      ),
      appVersion: const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '0.1.0',
      ),
      buildNumber: const String.fromEnvironment(
        'APP_BUILD',
        defaultValue: 'local',
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
  final String revenueCatPublicKeyIos;
  final String revenueCatPublicKeyAndroid;
  final String oneSignalAppId;
  final bool appleSignInEnabled;
  final String tosUrl;
  final String privacyUrl;
  final String appVersion;
  final String buildNumber;

  bool get isLocal => env == AppEnv.local;
  bool get isProduction => env == AppEnv.prod;
  bool get hasSupabase => supabaseAnonKey.isNotEmpty;
  bool get hasSentry => sentryDsn.isNotEmpty;
  bool get hasPosthog => posthogApiKey.isNotEmpty;
  bool get hasRevenueCat =>
      revenueCatPublicKeyIos.isNotEmpty ||
      revenueCatPublicKeyAndroid.isNotEmpty;
  bool get hasOneSignal => oneSignalAppId.isNotEmpty;

  String get release => 'pawdoc-mobile@$appVersion+$buildNumber';

  /// Validate that production builds have the critical integrations
  /// configured. Throws [StateError] when a prod build is missing
  /// something we cannot ship without (Sentry).
  ///
  /// Returns a list of *warnings* (non-fatal) for things that are merely
  /// "soft-required" in prod (RevenueCat, OneSignal). Callers should
  /// surface these to the developer via the structured logger.
  List<String> validate() {
    final warnings = <String>[];
    if (env == AppEnv.prod) {
      if (sentryDsn.isEmpty) {
        throw StateError(
          'SENTRY_DSN is required in production builds — see '
          'docs/environment-setup.md.',
        );
      }
      if (!hasRevenueCat) {
        warnings.add(
          'RevenueCat keys missing — paywall flow will be disabled.',
        );
      }
      if (!hasOneSignal) {
        warnings.add('OneSignal app id missing — push notifications disabled.');
      }
      if (!appleSignInEnabled) {
        warnings.add(
          'APPLE_SIGN_IN_ENABLED=false — App Store may reject submission '
          'until enabled.',
        );
      }
    }
    return warnings;
  }
}

/// Riverpod provider — overridden in `main.dart`. Reading this without the
/// override is a programmer error and throws at access time.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'appConfigProvider must be overridden in ProviderScope (see main.dart).',
  );
});
