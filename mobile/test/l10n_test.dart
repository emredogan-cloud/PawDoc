// Phase 5.4 — i18n smoke test. Proves the safety-critical UI strings resolve
// for both English and German, including the disclaimer (server-injected,
// safety-critical) and the EMERGENCY heading.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';

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
  testWidgets('English safety-critical strings resolve', (tester) async {
    AppLocalizations? l;
    await tester.pumpWidget(_probe(const Locale('en'), (x) => l = x));
    expect(l!.emergencyTitle, 'This may be an emergency');
    expect(l!.emergencyFindVet, contains('emergency vet'));
    expect(l!.emergencyDisclaimer, contains('not a diagnosis'));
    expect(l!.emergencyAcknowledge, contains('urgent attention'));
    expect(l!.actionContinue, 'Continue');
    expect(l!.telehealthCta, contains('vet'));
  });

  testWidgets('German safety-critical strings resolve', (tester) async {
    AppLocalizations? l;
    await tester.pumpWidget(_probe(const Locale('de'), (x) => l = x));
    expect(l!.emergencyTitle, 'Das könnte ein Notfall sein');
    expect(l!.emergencyFindVet, contains('Notfall-Tierarzt'));
    expect(l!.emergencyDisclaimer, contains('keine Diagnose'));
    expect(l!.actionContinue, 'Weiter');
    expect(l!.telehealthCta, contains('Tierarzt'));
  });

  test('Supported locales include en + de', () {
    final codes = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(codes.contains('en'), isTrue);
    expect(codes.contains('de'), isTrue);
  });
}
