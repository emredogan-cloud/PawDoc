// Next Evolution Phase 7 — Google Sign-In: controller orchestration + the
// no-dead-controls rule + terms gating on the button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/auth/auth_controller.dart';
import 'package:pawdoc/src/auth/sign_in_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient _dummyClient() => SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      // No auto-refresh timer — it would leak past widget-test teardown.
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

class _RecordingAuthController extends AuthController {
  _RecordingAuthController() : super(_dummyClient());
  int googleCalls = 0;

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
  }
}

void main() {
  group('AuthController.signInWithGoogle', () {
    test('cancelled sheet throws the quiet cancel marker, never the API',
        () async {
      final controller =
          AuthController(_dummyClient(), googleIdToken: () async => null);
      await expectLater(
        controller.signInWithGoogle(),
        throwsA(same(AuthController.googleCancelled)),
      );
    });

    test('fetcher failures propagate (surfaced as a friendly error upstream)',
        () async {
      final controller = AuthController(_dummyClient(),
          googleIdToken: () async => throw Exception('play services missing'));
      await expectLater(controller.signInWithGoogle(), throwsException);
    });
  });

  group('SignInScreen Google button', () {
    testWidgets('hidden entirely when no client id is configured (default)',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SignInScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('google_sign_in_button')), findsNothing);
    });

    testWidgets(
        'visible when configured, gated by terms assent, calls the controller',
        (tester) async {
      final auth = _RecordingAuthController();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          googleSignInAvailableProvider.overrideWithValue(true),
          authControllerProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: SignInScreen()),
      ));
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('google_sign_in_button'));
      await tester.scrollUntilVisible(button, 300,
          scrollable: find.byType(Scrollable).first);
      expect(button, findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Without terms assent the tap is inert (account creation gate).
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(auth.googleCalls, 0);

      // Assent, then it goes through.
      await tester.scrollUntilVisible(
          find.byKey(const Key('accept_terms_checkbox')), -300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('accept_terms_checkbox')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(button, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(auth.googleCalls, 1);
    });
  });
}
