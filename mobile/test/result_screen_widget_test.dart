/// Widget tests for AnalysisResultScreen — visual smoke for the three
/// triage levels + special flags (graceful degradation, cross-verify).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/app/theme.dart';
import 'package:pawdoc/features/analysis/analysis_result_screen.dart';
import 'package:pawdoc/shared/models/analysis_result.dart';

AnalysisResult _result({
  TriageLevel triage = TriageLevel.monitor,
  int tier = 3,
  bool emergencyOverride = false,
  bool crossVerifyDisagreement = false,
}) => AnalysisResult(
  analysisId: 'a-1',
  triageLevel: triage,
  confidence: 0.81,
  primaryConcern: 'Likely mild GI upset.',
  visibleSymptoms: const ['loose stool'],
  differential: const ['dietary indiscretion'],
  recommendedActions: const ['Bland diet for 24 hours.'],
  urgencyTimeframe: 'Within 24 hours.',
  disclaimerRequired: true,
  disclaimerText: 'PawDoc provides triage guidance, not a diagnosis.',
  modelUsed: 'claude-sonnet-x',
  tierUsed: tier,
  emergencyOverrideApplied: emergencyOverride,
  crossVerifyDisagreement: crossVerifyDisagreement,
  aiLatencyMs: 1234,
  requestId: 'req_test',
);

Widget _host(Widget child) => ProviderScope(
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  testWidgets('EMERGENCY result shows urgent headline + I-understand CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AnalysisResultScreen(result: _result(triage: TriageLevel.emergency)),
      ),
    );
    expect(find.text('Seek veterinary care immediately.'), findsOneWidget);
    expect(find.text('I understand'), findsOneWidget);
  });

  testWidgets('MONITOR result shows worth-a-vet-visit headline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(AnalysisResultScreen(result: _result(triage: TriageLevel.monitor))),
    );
    expect(find.text('Worth a vet visit soon.'), findsOneWidget);
    expect(find.text('Back home'), findsOneWidget);
  });

  testWidgets('NORMAL result shows routine headline', (tester) async {
    await tester.pumpWidget(
      _host(AnalysisResultScreen(result: _result(triage: TriageLevel.normal))),
    );
    expect(find.text('Looks routine for now.'), findsOneWidget);
  });

  testWidgets('emergency override applied surfaces a callout', (tester) async {
    await tester.pumpWidget(
      _host(
        AnalysisResultScreen(
          result: _result(
            triage: TriageLevel.emergency,
            tier: 1,
            emergencyOverride: true,
          ),
        ),
      ),
    );
    expect(find.text('Triggered by your description'), findsOneWidget);
  });

  testWidgets('graceful degradation surfaces a "limited" callout', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AnalysisResultScreen(
          result: _result(triage: TriageLevel.monitor, tier: 0),
        ),
      ),
    );
    expect(find.text('Limited analysis'), findsOneWidget);
  });

  testWidgets(
    'cross-verify disagreement is surfaced on non-emergency results',
    (tester) async {
      await tester.pumpWidget(
        _host(
          AnalysisResultScreen(
            result: _result(
              triage: TriageLevel.monitor,
              crossVerifyDisagreement: true,
            ),
          ),
        ),
      );
      expect(find.text("We're being cautious here"), findsOneWidget);
    },
  );

  testWidgets('disclaimer text always renders', (tester) async {
    await tester.pumpWidget(_host(AnalysisResultScreen(result: _result())));
    expect(
      find.textContaining('PawDoc provides triage guidance'),
      findsOneWidget,
    );
  });
}
