import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/delete_account_screen.dart';
import 'package:pawdoc/src/core/connectivity.dart';

void main() {
  testWidgets('Delete-account button is gated until you type DELETE', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DeleteAccountScreen())),
    );
    FilledButton button() =>
        tester.widget<FilledButton>(find.byKey(const Key('delete_account_button')));
    expect(button().onPressed, isNull); // disabled initially

    await tester.enterText(find.byKey(const Key('delete_confirm_field')), 'delete');
    await tester.pump();
    expect(button().onPressed, isNotNull); // case-insensitive confirmation enables it
  });

  testWidgets('Delete-account button exposes an accessibility label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DeleteAccountScreen())),
    );
    expect(find.bySemanticsLabel('Permanently delete my account'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('OfflineBanner shows a message when offline', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [connectivityProvider.overrideWith((ref) => Stream.value(false))],
      child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
    ));
    await tester.pump();
    expect(find.textContaining('No internet connection'), findsOneWidget);
  });

  testWidgets('OfflineBanner is hidden when online', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [connectivityProvider.overrideWith((ref) => Stream.value(true))],
      child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
    ));
    await tester.pump();
    expect(find.textContaining('No internet connection'), findsNothing);
  });
}
