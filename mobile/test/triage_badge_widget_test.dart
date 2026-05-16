/// Widget tests for the triage badge — color-coded chip with icon + label.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/app/theme.dart';
import 'package:pawdoc/shared/models/analysis_result.dart';
import 'package:pawdoc/shared/widgets/triage_badge.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('EMERGENCY renders red with warning icon + label', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const TriageBadge(level: TriageLevel.emergency)),
    );
    expect(find.text('EMERGENCY'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('MONITOR renders amber with visibility icon + label', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const TriageBadge(level: TriageLevel.monitor)),
    );
    expect(find.text('MONITOR'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('NORMAL renders green with check icon + label', (tester) async {
    await tester.pumpWidget(host(const TriageBadge(level: TriageLevel.normal)));
    expect(find.text('LIKELY NORMAL'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('large variant scales up label + icon', (tester) async {
    await tester.pumpWidget(
      host(const TriageBadge(level: TriageLevel.emergency, large: true)),
    );
    expect(find.text('EMERGENCY'), findsOneWidget);
  });
}
