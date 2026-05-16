/// Tests for the canonical disclaimer copy + widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/shared/widgets/disclaimer.dart';

void main() {
  test('kCanonicalDisclaimer mentions triage, not diagnosis, and vet', () {
    final lower = kCanonicalDisclaimer.toLowerCase();
    expect(lower, contains('triage guidance'));
    expect(lower, contains('not a veterinary diagnosis'));
    expect(lower, contains('veterinarian'));
  });

  test('kCanonicalDisclaimer is App-Store-safe wording', () {
    final lower = kCanonicalDisclaimer.toLowerCase();
    // We deliberately use "triage" and "diagnosis NOT". Direct
    // App-Store-flag terms must NOT appear in isolation.
    for (final taboo in const [
      'cure',
      'treatment',
      'prescribe',
      'guaranteed',
      'medically accurate',
    ]) {
      expect(lower.contains(taboo), isFalse, reason: 'leaked "$taboo"');
    }
  });

  testWidgets('DisclaimerCaption renders canonical copy when no override', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DisclaimerCaption())),
    );
    expect(find.textContaining('triage guidance'), findsOneWidget);
  });

  testWidgets('DisclaimerCaption honours explicit override text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DisclaimerCaption(text: 'Region-specific disclaimer XYZ.'),
        ),
      ),
    );
    expect(find.text('Region-specific disclaimer XYZ.'), findsOneWidget);
    expect(find.textContaining('triage guidance'), findsNothing);
  });

  testWidgets('DisclaimerCaption falls back to canonical on empty text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DisclaimerCaption(text: '')),
      ),
    );
    expect(find.textContaining('triage guidance'), findsOneWidget);
  });
}
