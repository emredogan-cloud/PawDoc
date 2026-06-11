// M3 celebration contract (matrix #14/#15 + acceptance): ≤2.5s, skippable by
// tap, reduce-motion → plain text snackbar (no overlay at all).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/celebration_overlay.dart';
import 'package:pawdoc/src/theme/app_assets.dart';

Widget _host({required bool reduceMotion}) => MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Builder(
              builder: (inner) => Center(
                child: FilledButton(
                  key: const Key('fire'),
                  onPressed: () => showCelebration(
                    inner,
                    motionAsset: AppMotionAssets.referralGiftOpen,
                    fallbackAsset: AppAssets.referralGiftOpen,
                    message: 'Reward unlocked',
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('reduce-motion: text snackbar only, no overlay dialog',
      (tester) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    await tester.tap(find.byKey(const Key('fire')));
    await tester.pump();

    expect(find.text('Reward unlocked'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('motion: overlay shows and a tap skips it immediately',
      (tester) async {
    await tester.pumpWidget(_host(reduceMotion: false));
    await tester.tap(find.byKey(const Key('fire')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Reward unlocked'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    // Tap anywhere = skip (never traps the user).
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('Reward unlocked'), findsNothing);
  });

  testWidgets('auto-dismisses within the ≤2.5s budget', (tester) async {
    await tester.pumpWidget(_host(reduceMotion: false));
    await tester.tap(find.byKey(const Key('fire')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Reward unlocked'), findsNothing);
  });
}
