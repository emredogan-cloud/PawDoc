// M0 fix F-3 — the EMERGENCY screen renders fully localized in the user's
// locale: the server's templated primary_concern and the wire urgency value
// are display-localized; unknown values pass through verbatim (never hidden).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/l10n/app_localizations_de.dart';
import 'package:pawdoc/l10n/app_localizations_en.dart';
import 'package:pawdoc/src/analysis/emergency_result_screen.dart';
import 'package:pawdoc/src/analysis/result_l10n.dart';
import 'package:pawdoc/src/models/analysis_result.dart';

AnalysisResult _override(String concern, {String urgency = 'immediately'}) =>
    AnalysisResult(
      triageLevel: TriageLevel.emergency,
      confidence: 1.0,
      primaryConcern: concern,
      visibleSymptoms: const [],
      differential: const [],
      recommendedActions: const ['Contact an emergency veterinarian now.'],
      urgencyTimeframe: urgency,
      disclaimerRequired: true,
    );

Widget _wrap(AnalysisResult r, {Locale? locale}) => ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EmergencyResultScreen(result: r),
      ),
    );

void main() {
  group('helpers', () {
    final en = AppLocalizationsEn();
    final de = AppLocalizationsDe();

    test('server template is localized; keyword preserved verbatim', () {
      expect(
        localizedPrimaryConcern(de, "Emergency indicator detected: 'atmet nicht'."),
        "Notfall-Anzeichen erkannt: 'atmet nicht'.",
      );
      expect(
        localizedPrimaryConcern(en, "Emergency indicator detected: 'not breathing'."),
        "Emergency indicator detected: 'not breathing'.",
      );
    });

    test('free-form AI concerns pass through unchanged', () {
      expect(localizedPrimaryConcern(de, 'Akute Atemnot beobachtet'),
          'Akute Atemnot beobachtet');
      expect(localizedPrimaryConcern(de, 'Severe respiratory distress'),
          'Severe respiratory distress');
    });

    test('urgency contract values map; unknown values pass through', () {
      expect(localizedUrgency(de, 'immediately'), 'sofort');
      expect(localizedUrgency(de, 'within 24 hours'), 'innerhalb von 24 Stunden');
      expect(localizedUrgency(de, 'routine'), 'routinemäßig');
      expect(localizedUrgency(en, 'immediately'), 'immediately');
      expect(localizedUrgency(de, 'within 2 hours'), 'within 2 hours');
    });
  });

  testWidgets('DE EMERGENCY has no mixed-language dynamic strings', (tester) async {
    await tester.pumpWidget(_wrap(
      _override("Emergency indicator detected: 'atmet nicht'."),
      locale: const Locale('de'),
    ));
    await tester.pump();

    expect(find.text("Notfall-Anzeichen erkannt: 'atmet nicht'."), findsOneWidget);
    expect(find.text('Empfohlen: sofort.'), findsOneWidget);
    expect(find.text('Das könnte ein Notfall sein'), findsOneWidget);

    // The two live-audit mixed-language fragments must be gone (F-3).
    expect(find.textContaining('Emergency indicator detected'), findsNothing);
    expect(find.textContaining('immediately'), findsNothing);
  });

  testWidgets('EN EMERGENCY renders the canonical English strings', (tester) async {
    await tester.pumpWidget(_wrap(
      _override("Emergency indicator detected: 'not breathing'."),
      locale: const Locale('en'),
    ));
    await tester.pump();

    expect(find.text("Emergency indicator detected: 'not breathing'."), findsOneWidget);
    expect(find.text('Recommended: immediately.'), findsOneWidget);
  });

  testWidgets('unknown dynamic values are shown verbatim, never hidden', (tester) async {
    await tester.pumpWidget(_wrap(
      _override('Suspected toxin ingestion', urgency: 'within 2 hours'),
      locale: const Locale('de'),
    ));
    await tester.pump();

    expect(find.text('Suspected toxin ingestion'), findsOneWidget);
    expect(find.text('Empfohlen: within 2 hours.'), findsOneWidget);
  });
}
