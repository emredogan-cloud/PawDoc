// Phase B — top-level error boundary. Proves an init failure surfaces a calm
// "couldn't start — retry" screen instead of a raw red stack trace (R09).
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/boot_error_app.dart';

void main() {
  testWidgets('BootErrorApp shows a calm retry screen with no raw error',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(BootErrorApp(onRetry: () => retries++));
    await tester.pumpAndSettle();

    expect(find.textContaining('PawDoc couldn'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('BootErrorApp without a retry callback hides the retry button',
      (tester) async {
    await tester.pumpWidget(const BootErrorApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('PawDoc couldn'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });
}
