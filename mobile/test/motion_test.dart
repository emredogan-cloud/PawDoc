// Phase C — motion foundation. Proves the reduce-motion contract: every
// primitive must render a static equivalent when animations are disabled.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/motion.dart';

Widget _wrap(Widget child, {bool reduce = false}) => MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

void main() {
  testWidgets('reduceMotion reflects MediaQuery.disableAnimations', (tester) async {
    late bool rm;
    Widget probe() => Builder(builder: (c) {
          rm = reduceMotion(c);
          return const SizedBox.shrink();
        });

    await tester.pumpWidget(_wrap(probe(), reduce: true));
    expect(rm, isTrue);

    await tester.pumpWidget(_wrap(probe(), reduce: false));
    expect(rm, isFalse);
  });

  testWidgets('AppButton renders a FilledButton and fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(AppButton(onPressed: () => taps++, child: const Text('Go'))));
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.text('Go'));
    expect(taps, 1);
  });

  testWidgets('AppButton with a null onPressed is disabled', (tester) async {
    await tester.pumpWidget(_wrap(const AppButton(onPressed: null, child: Text('Go'))));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('Skeleton shimmer is gated by reduce-motion', (tester) async {
    // Motion on → flutter_animate wrapper present.
    await tester.pumpWidget(_wrap(const Skeleton(width: 100)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Animate), findsOneWidget);

    // Motion off → static block, no shimmer (and pumpAndSettle must not hang).
    await tester.pumpWidget(_wrap(const Skeleton(width: 100), reduce: true));
    await tester.pumpAndSettle();
    expect(find.byType(Animate), findsNothing);
  });
}
