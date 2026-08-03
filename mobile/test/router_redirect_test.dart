// ENG-02/QA-02: the auth-redirect decision — the most brittle navigation in
// the app — as a pure function, exercised across every branch.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/router/app_router.dart';

void main() {
  group('computeRedirect', () {
    test('recovery session forces /recovery from anywhere', () {
      expect(computeRedirect(inRecovery: true, loggedIn: true, location: '/'),
          '/recovery');
      expect(
          computeRedirect(
              inRecovery: true, loggedIn: false, location: '/sign-in'),
          '/recovery');
      expect(
          computeRedirect(
              inRecovery: true, loggedIn: true, location: '/recovery'),
          isNull);
    });

    test('manual /recovery without a recovery session goes home', () {
      expect(
          computeRedirect(
              inRecovery: false, loggedIn: true, location: '/recovery'),
          '/');
    });

    test('signed out, fresh install: protected routes start the journey', () {
      // A brand-new install must see the app-open screen, not the sign-in form
      // — the pre-auth journey is 0001 -> onboarding -> gateway.
      for (final loc in ['/', '/pets', '/history', '/capture']) {
        expect(
            computeRedirect(
                inRecovery: false,
                loggedIn: false,
                location: loc,
                firstRunDone: false),
            '/welcome',
            reason: loc);
      }
    });

    test('signed out, journey already seen: protected routes go to the gateway',
        () {
      // A returning signed-out user does not replay eight onboarding pages.
      for (final loc in ['/', '/pets', '/history']) {
        expect(
            computeRedirect(
                inRecovery: false,
                loggedIn: false,
                location: loc,
                firstRunDone: true),
            '/auth-gateway',
            reason: loc);
      }
    });

    test('signed out: the pre-auth routes are reachable', () {
      for (final loc in ['/welcome', '/onboarding', '/auth-gateway', '/sign-in']) {
        expect(
            computeRedirect(
                inRecovery: false, loggedIn: false, location: loc,
                firstRunDone: false),
            isNull,
            reason: loc);
      }
    });

    test('signed in: the pre-auth routes bounce home', () {
      for (final loc in ['/sign-in', '/welcome', '/auth-gateway']) {
        expect(
            computeRedirect(inRecovery: false, loggedIn: true, location: loc),
            '/',
            reason: loc);
      }
    });

    test('signed in: /sign-in bounces home; app routes stay put', () {
      expect(
          computeRedirect(
              inRecovery: false, loggedIn: true, location: '/sign-in'),
          '/');
      for (final loc in ['/', '/pets', '/history', '/capture', '/symptom-text']) {
        expect(
            computeRedirect(inRecovery: false, loggedIn: true, location: loc),
            isNull,
            reason: loc);
      }
    });
  });
}
