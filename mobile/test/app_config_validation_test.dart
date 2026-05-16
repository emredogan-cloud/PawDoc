/// Tests for AppConfig.validate() — production env hardening.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/app/config.dart';

AppConfig _make({
  AppEnv env = AppEnv.prod,
  String sentry = '',
  String rcIos = '',
  String rcAndroid = '',
  String onesignal = '',
  bool apple = false,
}) => AppConfig(
  env: env,
  supabaseUrl: 'https://x.supabase.co',
  supabaseAnonKey: 'anon',
  aiServiceUrl: 'https://ai.example',
  sentryDsn: sentry,
  posthogApiKey: '',
  posthogHost: 'https://eu.posthog.com',
  revenueCatPublicKeyIos: rcIos,
  revenueCatPublicKeyAndroid: rcAndroid,
  oneSignalAppId: onesignal,
  appleSignInEnabled: apple,
);

void main() {
  test('prod build without Sentry DSN is a fatal config error', () {
    expect(() => _make(env: AppEnv.prod).validate(), throwsStateError);
  });

  test('prod build with Sentry but no RevenueCat produces a warning', () {
    final warns = _make(
      env: AppEnv.prod,
      sentry: 'https://abc@sentry.io/1',
    ).validate();
    expect(warns, contains(predicate<String>((s) => s.contains('RevenueCat'))));
  });

  test('prod build missing OneSignal produces a warning', () {
    final warns = _make(
      env: AppEnv.prod,
      sentry: 'https://abc@sentry.io/1',
      rcIos: 'appl_x',
      onesignal: '',
    ).validate();
    expect(warns, contains(predicate<String>((s) => s.contains('OneSignal'))));
  });

  test('prod build with Apple Sign-In disabled produces a warning', () {
    final warns = _make(
      env: AppEnv.prod,
      sentry: 'https://abc@sentry.io/1',
      rcIos: 'appl_x',
      onesignal: 'os_x',
      apple: false,
    ).validate();
    expect(
      warns,
      contains(predicate<String>((s) => s.contains('APPLE_SIGN_IN'))),
    );
  });

  test('fully-configured prod build produces zero warnings', () {
    final warns = _make(
      env: AppEnv.prod,
      sentry: 'https://abc@sentry.io/1',
      rcIos: 'appl_x',
      rcAndroid: 'goog_y',
      onesignal: 'os_x',
      apple: true,
    ).validate();
    expect(warns, isEmpty);
  });

  test('local builds never throw, never warn', () {
    final warns = _make(env: AppEnv.local).validate();
    expect(warns, isEmpty);
  });

  test('dev builds are equally lenient', () {
    final warns = _make(env: AppEnv.dev).validate();
    expect(warns, isEmpty);
  });

  test('release string includes version + build', () {
    final c = _make(env: AppEnv.local);
    expect(c.release, contains('pawdoc-mobile@'));
    expect(c.release, contains('+'));
  });

  test('hasRevenueCat true when either platform key present', () {
    expect(_make(rcIos: 'appl_x').hasRevenueCat, isTrue);
    expect(_make(rcAndroid: 'goog_y').hasRevenueCat, isTrue);
    expect(_make().hasRevenueCat, isFalse);
  });

  test('hasOneSignal mirrors the app id presence', () {
    expect(_make(onesignal: 'x').hasOneSignal, isTrue);
    expect(_make().hasOneSignal, isFalse);
  });
}
