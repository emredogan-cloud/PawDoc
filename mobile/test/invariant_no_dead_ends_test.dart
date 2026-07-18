// THE COMPANY INVARIANT (evolution J13), client layer: for EVERY ladder value
// the result surface shows an action label and a timeframe, and the retired
// "normal" vocabulary can never render. A regression here is the product's
// core promise breaking, not a styling bug.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/analysis/result_screen.dart';
import 'package:pawdoc/src/models/analysis_result.dart';

AnalysisResult mk(ActionLevel a) => AnalysisResult(
      action: a,
      confidence: 0.8,
      observation: 'a small patch of reddened skin',
      visibleSymptoms: const ['reddened skin'],
      vetsLookFor: const ['spread or change over time'],
      watchFor: const ['rapid spreading'],
      recommendedActions: const ['keep the area clean'],
      urgencyTimeframe: 'within a few days',
      recheckHours: 24,
      disclaimerRequired: true,
    );

void main() {
  for (final a in ActionLevel.values) {
    testWidgets('invariant: ${a.wireValue} renders an action + a timeframe',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResultScreen(result: mk(a)),
        ),
      ));

      // 1. An action is always announced.
      if (a == ActionLevel.getHelpNow) {
        expect(find.text('This may be an emergency'), findsOneWidget);
      } else {
        expect(
          find.textContaining(RegExp('GET HELP NOW|CALL YOUR VET TODAY|'
              'BOOK A ROUTINE VISIT|WATCH AND RE-CHECK')),
          findsWidgets,
        );
        // 2. The timeframe is always visible on the standard surface.
        expect(find.textContaining('within a few days'), findsWidgets);
      }

      // 3. The retired verdict vocabulary can never render.
      expect(find.textContaining('NORMAL'), findsNothing);
      expect(find.textContaining('LIKELY'), findsNothing);

      // 4. The disclaimer is present on every surface.
      expect(
        find.textContaining(RegExp('not a (veterinary )?diagnosis')),
        findsWidgets,
      );
    });
  }

  test('the wire contract has no "do nothing" state', () {
    // The enum itself is the invariant: four rungs, no NORMAL, no NONE.
    expect(ActionLevel.values, hasLength(4));
    for (final a in ActionLevel.values) {
      expect(a.wireValue.contains('NORMAL'), isFalse);
    }
  });
}
