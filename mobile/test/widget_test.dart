// Widget test: the sign-in screen renders its fields and auth options without
// needing an initialized Supabase backend (auth is only touched in callbacks).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/auth/sign_in_screen.dart';

void main() {
  testWidgets('SignInScreen shows email, password and auth buttons',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SignInScreen()),
      ),
    );

    expect(find.byKey(const Key('email_field')), findsOneWidget);
    expect(find.byKey(const Key('password_field')), findsOneWidget);
    expect(find.byKey(const Key('sign_in_button')), findsOneWidget);
    expect(find.byKey(const Key('sign_up_button')), findsOneWidget);
    expect(find.byKey(const Key('apple_sign_in_button')), findsOneWidget);
  });

  testWidgets('email field validates format before submit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SignInScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('email_field')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('password_field')), '12345');
    await tester.tap(find.byKey(const Key('sign_in_button')));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('At least 6 characters'), findsOneWidget);
  });

  // Phase E — honest trust footer (encryption + Privacy/Terms), no fake claims.
  testWidgets('SignInScreen shows an honest trust footer', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignInScreen())),
    );
    expect(find.text('Your data is encrypted.'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    // The reassurance subline is present; no fabricated metrics anywhere.
    expect(find.textContaining('vet-informed triage'), findsOneWidget);
  });
}
