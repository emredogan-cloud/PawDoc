// Next Evolution Phase 8 — premium welcome moment.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/monetization/premium_welcome.dart';

Widget _harness({bool restored = false}) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const Key('open'),
              onPressed: () =>
                  showPremiumWelcome(context, restored: restored),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders the thank-you, real benefits, and the honesty line',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premium_welcome_title')), findsOneWidget);
    expect(find.text('Welcome to Premium'), findsOneWidget);
    // Only REAL entitlements are promised.
    expect(find.text('Unlimited photo health checks'), findsOneWidget);
    expect(find.text('Unlimited Assistant conversations'), findsOneWidget);
    expect(find.text('Unlimited pet memories'), findsOneWidget);
    expect(find.text('PDF health reports included'), findsOneWidget);
    // The honesty line: premium never gates safety.
    expect(find.byKey(const Key('premium_welcome_honesty')), findsOneWidget);
    expect(find.textContaining('free for everyone'), findsOneWidget);
  });

  testWidgets('continue dismisses the moment', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.byKey(const Key('premium_welcome_continue')), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const Key('premium_welcome_continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('premium_welcome_title')), findsNothing);
  });

  testWidgets('restore variant welcomes the user back', (tester) async {
    await tester.pumpWidget(_harness(restored: true));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back to Premium'), findsOneWidget);
  });

  testWidgets('tapping the barrier does NOT dismiss (single clear CTA)',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('premium_welcome_title')), findsOneWidget);
  });
}
