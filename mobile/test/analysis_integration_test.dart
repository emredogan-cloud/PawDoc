// End-to-end integration with a MOCKED AI: override analysisServiceProvider
// with a fake so the runner's loading -> result transition is tested without a
// backend. This is how to mock the AI response for local e2e testing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/analysis/analysis_runner.dart';
import 'package:pawdoc/src/analysis/analysis_service.dart';
import 'package:pawdoc/src/models/analysis_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAnalysisService implements AnalysisService {
  FakeAnalysisService(this._result);
  final AnalysisResult _result;

  @override
  Future<AnalysisOutcome> analyze({
    required String petId,
    required String inputType,
    String? textDescription,
    String? imageStorageKey,
    List<String>? frameStorageKeys,
  }) async =>
      AnalysisOutcome(result: _result, analysisId: 'fake-id');
}

AnalysisResult mk(TriageLevel level) => AnalysisResult(
      triageLevel: level,
      confidence: 0.8,
      primaryConcern: 'Primary concern',
      visibleSymptoms: const [],
      differential: const [],
      recommendedActions: const ['do this'],
      urgencyTimeframe: 'within 24 hours',
      disclaimerRequired: true,
    );

Widget _runner(AnalysisResult result) => ProviderScope(
      overrides: [analysisServiceProvider.overrideWithValue(FakeAnalysisService(result))],
      child: MaterialApp(
        // Phase 5.4 — wire the l10n delegates so EMERGENCY screen renders.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AnalysisRunnerScreen(petId: 'p', petName: 'Rex', inputType: 'text', textDescription: 'tired'),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('mocked MONITOR analysis flows loading -> result', (tester) async {
    await tester.pumpWidget(_runner(mk(TriageLevel.monitor)));
    await tester.pump(); // resolve the analyze future
    await tester.pump(const Duration(milliseconds: 100)); // resolve prefs + rebuild
    expect(find.text('MONITOR — keep an eye out'), findsOneWidget);
  });

  testWidgets('mocked EMERGENCY analysis flows to the emergency screen', (tester) async {
    await tester.pumpWidget(_runner(mk(TriageLevel.emergency)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('This may be an emergency'), findsOneWidget);
  });
}
