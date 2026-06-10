// M0 fix F-2 — a completed analysis must invalidate latestTriageProvider so
// the home hero / pets chip can never show "No checks yet" after a check.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/l10n/app_localizations.dart';
import 'package:pawdoc/src/analysis/analysis_runner.dart';
import 'package:pawdoc/src/analysis/analysis_service.dart';
import 'package:pawdoc/src/models/analysis_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GatedAnalysisService implements AnalysisService {
  final completer = Completer<AnalysisOutcome>();

  @override
  Future<AnalysisOutcome> analyze({
    required String petId,
    required String inputType,
    String? textDescription,
    String? imageStorageKey,
    List<String>? frameStorageKeys,
  }) =>
      completer.future;
}

AnalysisResult _monitor() => const AnalysisResult(
      triageLevel: TriageLevel.monitor,
      confidence: 0.8,
      primaryConcern: 'Mild skin irritation',
      visibleSymptoms: [],
      differential: [],
      recommendedActions: ['keep the area clean'],
      urgencyTimeframe: 'within 24 hours',
      disclaimerRequired: true,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('analysis completion invalidates latestTriageProvider', (tester) async {
    var fetches = 0;
    LatestTriage? store; // backing "database": null until the check lands

    final service = _GatedAnalysisService();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        analysisServiceProvider.overrideWithValue(service),
        latestTriageProvider.overrideWith((ref, petId) {
          fetches++;
          return store;
        }),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnalysisRunnerScreen(
            petId: 'p1', petName: 'Rex', inputType: 'text', textDescription: 'tired'),
      ),
    ));

    // Subscribe like the home hero does, so the family member stays alive
    // (autoDispose) and a stale cached value COULD survive without the fix.
    final container = ProviderScope.containerOf(
        tester.element(find.byType(AnalysisRunnerScreen)),
        listen: false);
    final sub = container.listen(latestTriageProvider('p1'), (_, _) {});
    await tester.pump();
    expect(fetches, 1);
    expect(container.read(latestTriageProvider('p1')).value, isNull);

    // The check completes server-side; the runner must trigger a refetch.
    store = LatestTriage(level: 'MONITOR', checkedAt: DateTime.now());
    service.completer
        .complete(AnalysisOutcome(result: _monitor(), analysisId: 'a1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fetches, 2,
        reason: 'the runner must invalidate latestTriage on completion (F-2)');
    expect(container.read(latestTriageProvider('p1')).value?.level, 'MONITOR');
    sub.close();
  });
}
