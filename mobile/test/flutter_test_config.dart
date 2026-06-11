import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Auto-loaded by `flutter test` for every test in this package.
///
/// Two global test settings:
///
/// 1. `google_fonts` runtime fetching is disabled — there is no network in
///    CI/headless runs, so fonts resolve to the platform default instead of
///    attempting an HTTP request (deterministic; no "pending timer" from an
///    in-flight font download). App behavior is unchanged (runtime fetching
///    stays enabled outside tests).
///
/// 2. Animations are disabled (reduce-motion) for every test. PawDoc's motion
///    foundation (Phase C) gives every animation a static reduce-motion
///    equivalent, so this both exercises that path AND prevents pending-timer
///    failures from ambient/looping animations (e.g. the onboarding hero
///    "breathing" loop). Individual tests can still opt back into motion with a
///    local `MediaQuery` override (see test/motion_test.dart).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  // M1: AppMotionAsset pauses loops offscreen via VisibilityDetector, whose
  // default 500ms callback throttle leaves pending timers in widget tests.
  // Zero interval fires visibility callbacks in-frame (the package's
  // documented test setting); only tests that explicitly re-enable motion
  // via a MediaQuery override ever reach this code path.
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  await testMain();
}
