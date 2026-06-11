// M3 (#17): the one-time-ever "story has begun" toast — fires on the FIRST
// completed analysis only, and NEVER on an EMERGENCY result.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/analysis/analysis_runner.dart';
import 'package:pawdoc/src/analysis/analysis_service.dart';
import 'package:pawdoc/src/models/analysis_result.dart';
import 'package:pawdoc/src/monetization/paywall_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fake implements AnalysisService {
  _Fake(this.result);
  final AnalysisResult result;
  @override
  Future<AnalysisOutcome> analyze(
          {required String petId,
          required String inputType,
          String? textDescription,
          String? imageStorageKey,
          List<String>? frameStorageKeys}) async =>
      AnalysisOutcome(result: result, analysisId: 'a1');
}

AnalysisResult _mk(TriageLevel level) => AnalysisResult(
      triageLevel: level,
      confidence: 0.9,
      primaryConcern: 'Concern',
      visibleSymptoms: const [],
      differential: const [],
      recommendedActions: const ['do this'],
      urgencyTimeframe: 'routine',
      disclaimerRequired: true,
    );

Widget _runner(AnalysisResult r) => ProviderScope(
      overrides: [analysisServiceProvider.overrideWithValue(_Fake(r))],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnalysisRunnerScreen(
            petId: 'p1',
            petName: 'biscuit',
            petSpecies: 'dog',
            inputType: 'text',
            textDescription: 'tired'),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('markFirstAnalysisCompleted returns true exactly once', () async {
    expect(await PaywallPrefs.markFirstAnalysisCompleted(), isTrue);
    expect(await PaywallPrefs.markFirstAnalysisCompleted(), isFalse);
    expect(await PaywallPrefs.firstAnalysisCompleted(), isTrue);
  });

  testWidgets('first NORMAL check shows the story toast (text under RM)',
      (tester) async {
    await tester.pumpWidget(_runner(_mk(TriageLevel.normal)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Global test config runs reduce-motion -> the text-only confirmation.
    expect(find.textContaining('Biscuit’s story has begun'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // drain the snackbar timer
  });

  testWidgets('second check never repeats the toast', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'pawdoc.first_analysis_completed': true});
    await tester.pumpWidget(_runner(_mk(TriageLevel.normal)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('story has begun'), findsNothing);
  });

  testWidgets('EMERGENCY first check NEVER shows the toast', (tester) async {
    await tester.pumpWidget(_runner(_mk(TriageLevel.emergency)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('story has begun'), findsNothing);
    expect(find.text('This may be an emergency'), findsOneWidget);
  });
}
