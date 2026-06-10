import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Auto-loaded by `flutter test` for every test in this package.
///
/// PawDoc bundles its type system via `google_fonts` (Phase A design tokens).
/// In CI/headless test runs there is no network, so we disable runtime font
/// fetching: google_fonts then resolves to the platform default font instead of
/// attempting an HTTP request. This keeps tests deterministic and prevents
/// "pending timer" failures from in-flight font downloads. It does NOT change
/// any app behavior — at runtime fetching stays enabled (and cached).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
