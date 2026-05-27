import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/onboarding/onboarding_flow.dart';
import 'package:pawdoc/src/text_input/symptom_text_screen.dart';

void main() {
  testWidgets('Onboarding opens on the value-hook screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingFlow())),
    );
    expect(find.text('Never wonder if your pet needs the vet again.'), findsOneWidget);
    expect(find.byKey(const Key('onb_get_started')), findsOneWidget);
  });

  testWidgets('Symptom text Continue is gated by minimum character guidance',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SymptomTextScreen(petName: 'Rex')),
    );
    // Too short initially.
    expect(find.textContaining('Add a little more detail'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('symptom_text_field')),
      'Since this morning Rex has been very tired and is not eating his food.',
    );
    await tester.pump();
    expect(find.text('Looks good.'), findsOneWidget);
  });
}
