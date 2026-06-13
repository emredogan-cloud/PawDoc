// GAP-E16: a short message naming a critical sign must NEVER be blocked by the
// min-length gate ("No choking-style emergency message is blocked").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/motion.dart';
import 'package:pawdoc/src/text_input/symptom_text_screen.dart';

void main() {
  Future<void> pump(WidgetTester t) =>
      t.pumpWidget(const MaterialApp(home: SymptomTextScreen(petName: 'Rex')));

  AppButton button(WidgetTester t) =>
      t.widget<AppButton>(find.byKey(const Key('symptom_continue_button')));

  Future<void> type(WidgetTester t, String s) async {
    await t.enterText(find.byKey(const Key('symptom_text_field')), s);
    await t.pump();
  }

  testWidgets('short emergency phrase ("choking") is NOT blocked', (t) async {
    await pump(t);
    await type(t, 'choking'); // 7 chars, well under the 12 min
    expect(button(t).onPressed, isNotNull,
        reason: 'an emergency phrase must never be gated by length');
  });

  testWidgets('"he\'s choking" (12) is allowed', (t) async {
    await pump(t);
    await type(t, "he's choking");
    expect(button(t).onPressed, isNotNull);
  });

  testWidgets('short non-emergency text IS gated (< 12 chars)', (t) async {
    await pump(t);
    await type(t, 'sick');
    expect(button(t).onPressed, isNull);
  });

  testWidgets('12+ char normal description is allowed', (t) async {
    await pump(t);
    await type(t, 'tired all day today');
    expect(button(t).onPressed, isNotNull);
  });
}
