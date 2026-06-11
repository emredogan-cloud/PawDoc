// M0 fix F-1 — the delete screen's escape route must NEVER be disabled, and a
// failure must re-enable the flow with a clear message (no infinite spinner).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/account/account_service.dart';
import 'package:pawdoc/src/account/delete_account_screen.dart';

class _HangingAccountService implements AccountService {
  int calls = 0;
  @override
  Future<void> deleteAccount() {
    calls++;
    return Completer<void>().future; // never completes — the F-1 hang
  }
}

class _OkAccountService implements AccountService {
  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _FailingAccountService implements AccountService {
  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    throw TimeoutException('delete-account timed out');
  }
}

Widget _host(AccountService service) => ProviderScope(
      overrides: [accountServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open_delete'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _openAndArm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_delete')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('delete_confirm_field')), 'DELETE');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Cancel stays usable while "Deleting…" and pops the screen',
      (tester) async {
    final service = _HangingAccountService();
    await tester.pumpWidget(_host(service));
    await _openAndArm(tester);

    await tester.tap(find.byKey(const Key('delete_account_button')));
    await tester.pump();

    expect(find.text('Deleting…'), findsOneWidget);
    expect(service.calls, 1);

    // The escape route is never disabled (F-1 acceptance).
    final cancel =
        tester.widget<TextButton>(find.byKey(const Key('delete_cancel_button')));
    expect(cancel.onPressed, isNotNull,
        reason: 'Cancel must stay enabled during deletion');

    await tester.tap(find.byKey(const Key('delete_cancel_button')));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsNothing);
  });

  testWidgets('failure shows the message and re-enables the button',
      (tester) async {
    await tester.pumpWidget(_host(_FailingAccountService()));
    await _openAndArm(tester);

    await tester.tap(find.byKey(const Key('delete_account_button')));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Could not delete the account'), findsOneWidget);
    expect(find.text('Delete my account'), findsOneWidget); // busy state cleared
    final button = tester
        .widget<FilledButton>(find.byKey(const Key('delete_account_button')));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('successful deletion pops the pushed stack itself (D-6)',
      (tester) async {
    await tester.pumpWidget(_host(_OkAccountService()));
    await _openAndArm(tester);

    await tester.tap(find.byKey(const Key('delete_account_button')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // The router's redirect happens beneath plain pushed routes (live
    // finding D-6) — the screen must dismiss itself on success.
    expect(find.byType(DeleteAccountScreen), findsNothing);
  });

  testWidgets('delete stays disarmed until DELETE is typed', (tester) async {
    await tester.pumpWidget(_host(_HangingAccountService()));
    await tester.tap(find.byKey(const Key('open_delete')));
    await tester.pumpAndSettle();

    final button = tester
        .widget<FilledButton>(find.byKey(const Key('delete_account_button')));
    expect(button.onPressed, isNull);
  });
}
