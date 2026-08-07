// Guards for the pre-auth journey: app-open (0001) -> onboarding -> gateway (000).
//
// The routing change is the risky part. Onboarding now runs *before*
// authentication, so the auth redirect had to stop sending every signed-out
// user to /sign-in — and getting that wrong either traps a new install on the
// sign-in form or lets an unauthenticated user reach a protected screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/onboarding/auth_gateway_screen.dart';
import 'package:pawdoc/src/onboarding/first_run_screen.dart';
import 'package:pawdoc/src/theme/design_tokens.dart';
import 'package:pawdoc/src/onboarding/onboarding_ui.dart';
import 'package:pawdoc/src/theme/paw_components.dart';

Widget _host(Widget child,
        {Size size = const Size(390, 844), double textScale = 1.0}) =>
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, textTheme: AppType.textTheme()),
        home: child,
      ),
    );

void main() {
  group('app-open screen (0001)', () {
    testWidgets('renders the reference composition', (tester) async {
      await tester.pumpWidget(_host(
          FirstRunScreen(onStart: () {}, onSignIn: () {})));
      await tester.pump();

      expect(find.textContaining('Welcome to', findRichText: true),
          findsWidgets);
      expect(
          find.textContaining('AI-powered pet health companion',
              findRichText: true),
          findsWidgets);
      expect(find.text('Let\'s Start Your Pet\'s Journey'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      // All four feature columns, not a subset.
      for (final t in [
        'AI Insights',
        'Emergency',
        'Smart Reminders',
        'Health Diary'
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }

      // Two artwork plates: the logo lockup and the hero.
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('both callbacks fire', (tester) async {
      var start = 0, signIn = 0;
      await tester.pumpWidget(_host(FirstRunScreen(
          onStart: () => start++, onSignIn: () => signIn++)));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('firstrun_start')));
      await tester.tap(find.byKey(const Key('firstrun_start')));
      await tester.ensureVisible(find.byKey(const Key('firstrun_sign_in')));
      await tester.tap(find.byKey(const Key('firstrun_sign_in')));
      expect(start, 1);
      expect(signIn, 1);
    });

    testWidgets('is System A, never the in-app lime', (tester) async {
      late PawTone tone;
      await tester.pumpWidget(_host(FirstRunScreen(
        onStart: () {},
        onSignIn: () {},
      )));
      await tester.pump();
      tone = PawTone.of(tester.element(find.byType(OnbStepLabel).first));
      expect(tone.accent, AppColors.emerald500);
      expect(tone.accent, isNot(AppColors.lime500));
    });

    testWidgets('scrolls rather than overflowing at 320dp / 200%', (tester) async {
      await tester.pumpWidget(_host(
        FirstRunScreen(onStart: () {}, onSignIn: () {}),
        size: const Size(320, 640),
        textScale: 2.0,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('auth gateway (000)', () {
    testWidgets('offers all three ways in', (tester) async {
      await tester.pumpWidget(_host(AuthGatewayScreen(
          onGoogle: () {}, onEmail: () {}, onGuest: () {})));
      await tester.pump();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Email'), findsOneWidget);

      // The four capability cards from the reference.
      for (final t in ['AI Insights', 'Health Diary', 'Reminders']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });

    testWidgets('each route fires its own callback', (tester) async {
      var g = 0, e = 0, guest = 0;
      await tester.pumpWidget(_host(AuthGatewayScreen(
        onGoogle: () => g++,
        onEmail: () => e++,
        onGuest: () => guest++,
      )));
      await tester.pump();

      for (final k in ['gateway_google', 'gateway_email', 'gateway_get_started']) {
        await tester.ensureVisible(find.byKey(Key(k)));
        await tester.tap(find.byKey(Key(k)));
      }
      expect([g, e, guest], [1, 1, 1]);
    });

    testWidgets('busy disables every action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(AuthGatewayScreen(
        busy: true,
        onGoogle: () => taps++,
        onEmail: () => taps++,
        onGuest: () => taps++,
      )));
      await tester.pump();
      for (final k in ['gateway_google', 'gateway_email']) {
        await tester.ensureVisible(find.byKey(Key(k)));
        await tester.tap(find.byKey(Key(k)));
      }
      expect(taps, 0, reason: 'a second tap must not start a second sign-in');
    });
  });
}
