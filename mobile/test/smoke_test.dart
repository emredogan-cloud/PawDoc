/// Foundational smoke tests.
///
/// Phase 0's widget-mount checks have moved to feature-specific widget
/// tests now that the app shell requires a real Supabase singleton.
/// What remains here is the config-parsing surface — the smallest piece
/// of the boot path that runs identically in unit-test and on device.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/app/config.dart';

void main() {
  test('AppConfig env parsing is case-insensitive', () {
    expect(AppEnv.parse('PROD'), AppEnv.prod);
    expect(AppEnv.parse('dev'), AppEnv.dev);
    expect(AppEnv.parse('LOCAL'), AppEnv.local);
    expect(AppEnv.parse('unknown'), AppEnv.local);
  });

  test('AppConfig defaults for local are sane', () {
    const AppConfig config = AppConfig(
      env: AppEnv.local,
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseAnonKey: 'key',
      aiServiceUrl: 'http://localhost:8080',
      sentryDsn: '',
      posthogApiKey: '',
      posthogHost: 'https://eu.posthog.com',
    );
    expect(config.isLocal, isTrue);
    expect(config.isProduction, isFalse);
    expect(config.hasSupabase, isTrue);
    expect(config.hasSentry, isFalse);
    expect(config.hasPosthog, isFalse);
  });

  test('AppConfig.fromEnvironment uses safe local defaults', () {
    // Without any --dart-define overrides, the binary should still boot
    // pointed at localhost. This guards against accidental
    // "compile-time-required" env vars.
    final config = AppConfig.fromEnvironment();
    expect(config.env, AppEnv.local);
    expect(config.supabaseUrl.contains('127.0.0.1'), isTrue);
  });
}
