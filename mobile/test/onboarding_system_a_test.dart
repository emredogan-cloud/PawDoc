// Onboarding rebuild guard (mockups 002-009).
//
// Two things need pinning. First, System A isolation: onboarding is navy +
// emerald + cyan, and since the shared accent palette now resolves to lime, an
// undeclared subtree silently renders the wrong system.
//
// Second — and this is the reason the file exists — three of the onboarding
// mockups depict product output that breaks the safety contract, and a future
// pass "restoring fidelity to the design" would reintroduce them:
//
//   003  "No critical signs detected"                      (all-clear, V-14)
//   005  "Mild coughing detected" + a `Low` badge          (finding + grade)
//   006  "...mild irritants, allergies, or infections"     (names causes, V-13)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/onboarding/onboarding_flow.dart';
import 'package:pawdoc/src/onboarding/onboarding_ui.dart';
import 'package:pawdoc/src/theme/design_tokens.dart';
import 'package:pawdoc/src/theme/paw_components.dart';

Widget _host({double textScale = 1.0, Size size = const Size(390, 844)}) =>
    ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(
            size: size, textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, textTheme: AppType.textTheme()),
          home: const OnboardingFlow(),
        ),
      ),
    );

/// `_advance()` awaits an analytics capture; stub the channel so it resolves.
void _stubAnalytics(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('posthog_flutter'),
    (call) async => null,
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), null));
}

/// Collects every rendered string on the current page.
String _visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

void main() {
  group('System A isolation', () {
    testWidgets('onboarding resolves to emerald on navy, never lime',
        (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump();

      final tone = PawTone.of(
          tester.element(find.byType(OnbHeader).first));
      expect(tone.accent, AppColors.emerald500);
      expect(tone.canvas, AppColors.navy900);
      expect(tone.accent, isNot(AppColors.lime500),
          reason: 'the in-app lime must not leak into onboarding');
    });
  });

  group('safety: the mockups\' violating copy is not reproduced', () {
    testWidgets('no all-clear or severity grade on the AI-insights sample',
        (tester) async {
      _stubAnalytics(tester);
      await tester.pumpWidget(_host());
      await tester.ensureVisible(find.byKey(const Key('onb_get_started')));
      await tester.tap(find.byKey(const Key('onb_get_started')));
      await tester.pumpAndSettle();

      final text = _visibleText(tester).toLowerCase();
      for (final banned in [
        'no critical signs',
        'low urgency',
        'monitor at home',
        'detected',
      ]) {
        expect(text.contains(banned), isFalse,
            reason: 'onboarding must not depict "$banned" (review V-14)');
      }

      // And it must still terminate with an action AND a timeframe.
      expect(text.contains('24–48 hours'), isTrue,
          reason: 'the sample result must carry a timeframe');
      expect(text.contains('not a diagnosis'), isTrue,
          reason: 'the sample result must carry its disclaimer');
    });

    testWidgets('neither assistant sample names a condition', (tester) async {
      _stubAnalytics(tester);
      await tester.pumpWidget(_host());
      // value -> insights -> emergency -> diary -> assistant intro (006)
      for (final k in [
        'onb_get_started',
        'onb_next_emergency',
        'onb_next_diary',
        'onb_next_assistant',
      ]) {
        await tester.ensureVisible(find.byKey(Key(k)));
        await tester.tap(find.byKey(Key(k)));
        await tester.pumpAndSettle();
      }

      const banned = ['allergies', 'infection', 'irritants', 'can be caused by'];

      // 006 is the mockup that names three conditions as causes.
      var text = _visibleText(tester).toLowerCase();
      for (final b in banned) {
        expect(text.contains(b), isFalse,
            reason: 'mockup 006\'s sample must not name a cause (review V-13)');
      }
      expect(text.contains('contact your veterinarian'), isTrue,
          reason: 'the 006 sample must still close on a vet referral');

      // 007 is the compliant reference the review points at.
      await tester.ensureVisible(find.byKey(const Key('onb_next_chat')));
      await tester.tap(find.byKey(const Key('onb_next_chat')));
      await tester.pumpAndSettle();

      text = _visibleText(tester).toLowerCase();
      for (final b in banned) {
        expect(text.contains(b), isFalse,
            reason: 'the assistant sample must not name a cause (review V-13)');
      }
      expect(text.contains('many reasons'), isTrue,
          reason: 'it should use the compliant framing from mockup 007');
      expect(text.contains('consult your veterinarian'), isTrue);
    });

    testWidgets('the diary sample carries no severity grade', (tester) async {
      _stubAnalytics(tester);
      await tester.pumpWidget(_host());
      for (final k in [
        'onb_get_started',
        'onb_next_emergency',
        'onb_next_diary',
      ]) {
        await tester.ensureVisible(find.byKey(Key(k)));
        await tester.tap(find.byKey(Key(k)));
        await tester.pumpAndSettle();
      }

      final text = _visibleText(tester).toLowerCase();
      // Mockup 005 draws "Mild coughing detected", a `Low` badge and
      // "Monitor at home" — a finding, a grade, and a terminating instruction.
      for (final banned in ['detected', 'monitor at home', 'low urgency']) {
        expect(text.contains(banned), isFalse,
            reason: 'the diary sample must not depict "$banned" (review V-14)');
      }
      expect(text.contains('24–48 hours'), isTrue,
          reason: 'the diary sample must still carry a recheck window');
    });
  });

  group('flow', () {
    testWidgets('eight steps, and the pet picker still renders', (tester) async {
      _stubAnalytics(tester);
      await tester.pumpWidget(_host());

      Finder progress(String label) => find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label);
      expect(progress('Step 1 of 8'), findsOneWidget);

      // One page per mockup, 002-009, so the add-pet page (008) is step 7.
      for (final k in [
        'onb_get_started',
        'onb_next_emergency',
        'onb_next_diary',
        'onb_next_assistant',
        'onb_next_chat',
        'onb_next_pet',
      ]) {
        await tester.ensureVisible(find.byKey(Key(k)));
        await tester.tap(find.byKey(Key(k)));
        await tester.pumpAndSettle();
      }

      expect(progress('Step 7 of 8'), findsOneWidget);
      // Species chips moved from step 2 to the add-pet step; they must survive
      // the rebuild with their plain-text labels (a11y: the emoji-only gap).
      expect(find.text('Dog'), findsOneWidget);
      expect(find.text('Cat'), findsOneWidget);
      expect(find.text('Guinea pig'), findsOneWidget);
      expect(find.byKey(const Key('onb_pet_name')), findsOneWidget);
      expect(find.byKey(const Key('onb_pet_continue')), findsOneWidget);
    });

    testWidgets('Skip is reachable on the first page', (tester) async {
      await tester.pumpWidget(_host());
      expect(find.byKey(const Key('onb_skip')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('onb_skip'))).height,
          greaterThanOrEqualTo(48));
    });

    testWidgets('renders at 320dp and 200% text scale without overflow',
        (tester) async {
      await tester.pumpWidget(
          _host(size: const Size(320, 640), textScale: 2.0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
