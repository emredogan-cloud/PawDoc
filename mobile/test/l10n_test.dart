// Phase 5.4 — i18n smoke test. Proves the safety-critical UI strings resolve
// for both English and German, including the disclaimer (server-injected,
// safety-critical) and the EMERGENCY heading.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/app.dart' show resolveAppLocale;

Widget _probe(Locale locale, void Function(AppLocalizations) onBuild) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        onBuild(AppLocalizations.of(context)!);
        return const SizedBox.shrink();
      }),
    );

void main() {
  group('resolveAppLocale fallback (unsupported -> English, never German)', () {
    const supported = [Locale('de'), Locale('en')]; // generated order: de first
    test('Turkish (unsupported) falls back to English, NOT German', () {
      expect(resolveAppLocale(const [Locale('tr', 'TR')], supported),
          const Locale('en'));
    });
    test('German device resolves to German', () {
      expect(resolveAppLocale(const [Locale('de', 'DE')], supported).languageCode, 'de');
    });
    test('English (any region) resolves to English', () {
      expect(resolveAppLocale(const [Locale('en', 'US')], supported).languageCode, 'en');
    });
    test('empty / null device list falls back to English', () {
      expect(resolveAppLocale(const [], supported), const Locale('en'));
      expect(resolveAppLocale(null, supported), const Locale('en'));
    });
    test('first supported match in the device list wins (fr,de -> de)', () {
      expect(resolveAppLocale(const [Locale('fr'), Locale('de')], supported).languageCode, 'de');
    });
  });

  testWidgets('English safety-critical strings resolve', (tester) async {
    AppLocalizations? l;
    await tester.pumpWidget(_probe(const Locale('en'), (x) => l = x));
    expect(l!.emergencyTitle, 'This may be an emergency');
    expect(l!.emergencyFindVet, contains('emergency vet'));
    expect(l!.emergencyDisclaimer, contains('not a diagnosis'));
    expect(l!.emergencyAcknowledge, contains('urgent attention'));
    expect(l!.actionContinue, 'Continue');
  });

  testWidgets('German safety-critical strings resolve', (tester) async {
    AppLocalizations? l;
    await tester.pumpWidget(_probe(const Locale('de'), (x) => l = x));
    expect(l!.emergencyTitle, 'Das könnte ein Notfall sein');
    expect(l!.emergencyFindVet, contains('Notfall-Tierarzt'));
    expect(l!.emergencyDisclaimer, contains('keine Diagnose'));
    expect(l!.actionContinue, 'Weiter');
  });

  test('Supported locales include en + de', () {
    final codes = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(codes.contains('en'), isTrue);
    expect(codes.contains('de'), isTrue);
  });
}
