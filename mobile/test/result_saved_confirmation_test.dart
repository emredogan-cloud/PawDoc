// M1 (matrix #7): "Saved to {Pet}'s history" appears on the standard result —
// only when the analysis row truly stored (honesty rule), never blocking Done.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/analysis/result_screen.dart';
import 'package:pawdoc/src/models/analysis_result.dart';

AnalysisResult _monitor() => const AnalysisResult(
      action: ActionLevel.callToday,
      confidence: 0.8,
      observation: 'Mild irritation',
      visibleSymptoms: ['redness'],
      vetsLookFor: [],
      watchFor: [],
      recommendedActions: ['keep the area clean'],
      urgencyTimeframe: 'within 24 hours',
      recheckHours: null,
      disclaimerRequired: true,
    );

Widget _wrap({String? analysisId, String? petName, bool reduceMotion = false}) =>
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: ResultScreen(
                result: _monitor(), analysisId: analysisId, petName: petName),
          ),
        ),
      ),
    );

void main() {
  testWidgets('confirmation shows when the analysis stored', (tester) async {
    await tester.pumpWidget(_wrap(analysisId: 'a1', petName: 'biscuit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byKey(const Key('result_saved_confirmation')), findsOneWidget);
    expect(find.textContaining('Saved to Biscuit’s history'), findsOneWidget);
    // Done stays enabled — celebrations never block navigation (lazy ListView:
    // scroll it into build range first).
    await tester.dragUntilVisible(find.byKey(const Key('result_done')),
        find.byType(ListView), const Offset(0, -200));
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('result_done')))
            .onPressed,
        isNotNull);
  });

  testWidgets('no confirmation when the row failed to store', (tester) async {
    await tester.pumpWidget(_wrap(analysisId: null, petName: 'biscuit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byKey(const Key('result_saved_confirmation')), findsNothing);
  });

  testWidgets('reduce-motion: confirmation is static and immediate', (tester) async {
    await tester.pumpWidget(
        _wrap(analysisId: 'a1', petName: 'biscuit', reduceMotion: true));
    await tester.pump();

    expect(find.byKey(const Key('result_saved_confirmation')), findsOneWidget);
  });
}
