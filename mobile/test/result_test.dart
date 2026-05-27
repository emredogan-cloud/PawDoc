import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/analysis/result_screen.dart';
import 'package:pawdoc/src/models/analysis_result.dart';

AnalysisResult mk(TriageLevel level) => AnalysisResult(
      triageLevel: level,
      confidence: 0.8,
      primaryConcern: 'Primary concern',
      visibleSymptoms: const ['a symptom'],
      differential: const ['a cause'],
      recommendedActions: const ['do this first'],
      urgencyTimeframe: 'within 24 hours',
      disclaimerRequired: true,
    );

Widget _wrap(AnalysisResult r) =>
    ProviderScope(child: MaterialApp(home: ResultScreen(result: r)));

void main() {
  testWidgets('NORMAL result shows badge, disclaimer, and Share', (tester) async {
    await tester.pumpWidget(_wrap(mk(TriageLevel.normal)));
    expect(find.text('LIKELY NORMAL'), findsOneWidget);
    expect(find.byKey(const Key('result_share')), findsOneWidget);
    expect(find.textContaining('information, not a veterinary diagnosis'), findsOneWidget);
  });

  testWidgets('MONITOR result has no Share button', (tester) async {
    await tester.pumpWidget(_wrap(mk(TriageLevel.monitor)));
    expect(find.text('MONITOR — keep an eye out'), findsOneWidget);
    expect(find.byKey(const Key('result_share')), findsNothing);
  });

  testWidgets('EMERGENCY routes to the gated emergency screen', (tester) async {
    await tester.pumpWidget(_wrap(mk(TriageLevel.emergency)));
    expect(find.text('This may be an emergency'), findsOneWidget);
    expect(find.byKey(const Key('emergency_find_vet')), findsOneWidget);

    // Continue is gated until the user acknowledges.
    FilledButton cont() =>
        tester.widget<FilledButton>(find.byKey(const Key('emergency_continue')));
    expect(cont().onPressed, isNull);
    await tester.tap(find.byKey(const Key('emergency_ack_checkbox')));
    await tester.pump();
    expect(cont().onPressed, isNotNull);
  });
}
