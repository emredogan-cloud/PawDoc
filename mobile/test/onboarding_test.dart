import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Phase D — scaffold: labeled progress + Skip, and labeled species chips.
  testWidgets('Onboarding shows progress, Skip, and labeled species chips',
      (tester) async {
    Finder progress(String label) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label);

    // _advance() awaits an analytics capture; stub the PostHog channel so it
    // completes (otherwise it never resolves in the headless test environment).
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('posthog_flutter'),
      (call) async => null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingFlow())),
    );
    // Header on step 1: progress label + a reachable Skip.
    expect(progress('Step 1 of 4'), findsOneWidget);
    expect(find.byKey(const Key('onb_skip')), findsOneWidget);

    // Advancing to pet setup (step 1 -> 2 is provider-free).
    await tester.tap(find.byKey(const Key('onb_get_started')));
    await tester.pumpAndSettle();
    expect(progress('Step 2 of 4'), findsOneWidget);

    // Custom species chips render with plain-text labels (a11y: emoji gap fixed).
    expect(find.text('Dog'), findsOneWidget);
    expect(find.text('Cat'), findsOneWidget);
    expect(find.text('Guinea pig'), findsOneWidget);
  });

  testWidgets('Symptom text Continue is gated by minimum character guidance',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
          child: MaterialApp(home: SymptomTextScreen(petName: 'Rex'))),
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
