/// Smoke tests for the Phase 0 foundation.
///
/// These guard the seams that Phase 1 will build on:
///   - The app boots without throwing
///   - The Material 3 theme is applied
///   - The splash route renders the brand mark
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/app/app.dart';
import 'package:pawdoc/app/config.dart';

void main() {
  AppConfig testConfig() {
    return const AppConfig(
      env: AppEnv.local,
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseAnonKey: 'test-anon-key',
      aiServiceUrl: 'http://localhost:8080',
      sentryDsn: '',
      posthogApiKey: '',
      posthogHost: 'https://eu.posthog.com',
    );
  }

  testWidgets('app boots and shows PawDoc brand mark', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(testConfig())],
        child: const PawDocApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PawDoc'), findsOneWidget);
    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
  });

  testWidgets('uses Material 3', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(testConfig())],
        child: const PawDocApp(),
      ),
    );
    final BuildContext context = tester.element(find.text('PawDoc'));
    final ThemeData theme = Theme.of(context);
    expect(theme.useMaterial3, isTrue);
  });

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
}
