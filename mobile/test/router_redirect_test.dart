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

    test('signed out: everything except /sign-in redirects to /sign-in', () {
      for (final loc in ['/', '/pets', '/history', '/capture']) {
        expect(
            computeRedirect(inRecovery: false, loggedIn: false, location: loc),
            '/sign-in',
            reason: loc);
      }
      expect(
          computeRedirect(
              inRecovery: false, loggedIn: false, location: '/sign-in'),
          isNull);
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
