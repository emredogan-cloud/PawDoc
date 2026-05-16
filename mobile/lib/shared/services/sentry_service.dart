/// Mobile-side Sentry wiring.
///
/// Discipline:
/// - `SentryFlutter.init` runs only when a DSN is configured. Local dev
///   builds boot without it and no events are captured.
/// - We strip auth tokens, raw request bodies, and user emails via
///   `beforeSend` (defence in depth — Sentry's defaults also scrub).
/// - We do NOT attach images, screenshots, or location data. The app
///   never sends pet images to Sentry.
///
/// Releases are tagged `pawdoc-mobile@<version>+<build>` so the Sentry
/// dashboard groups errors by build.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../app/config.dart';

/// Wrap [appRunner] with Sentry capture if a DSN is configured; otherwise
/// runs [appRunner] directly.
Future<void> runWithSentry(
  AppConfig config,
  FutureOr<void> Function() appRunner,
) async {
  if (!config.hasSentry) {
    await appRunner();
    return;
  }
  await SentryFlutter.init((options) {
    // Sentry's profiling + view hierarchy fields are marked experimental
    // in the SDK; we accept the API stability risk because they're
    // valuable for diagnosing release crashes.
    // ignore_for_file: experimental_member_use
    options
      ..dsn = config.sentryDsn
      ..environment = config.env.name
      ..release = config.release
      ..tracesSampleRate = 0.1
      ..profilesSampleRate = 0.0
      ..sendDefaultPii = false
      ..attachScreenshot = false
      ..attachViewHierarchy = false
      ..beforeSend = _scrub;
  }, appRunner: () async => appRunner());
}

/// Strip secrets + PII from outgoing events.
FutureOr<SentryEvent?> _scrub(SentryEvent event, Hint hint) {
  // Drop request body + sensitive headers. We construct a fresh
  // SentryRequest rather than copyWith — copyWith doesn't differentiate
  // "leave it" from "set to null", which would leave `data` populated.
  final request = event.request;
  if (request != null) {
    event = event.copyWith(
      request: SentryRequest(
        url: request.url,
        method: request.method,
        headers: _filterHeaders(request.headers) ?? const {},
        // body + queryString deliberately omitted → null
      ),
    );
  }
  // Strip email + IP from user; keep `id` (UUID) for joining traces.
  final user = event.user;
  if (user != null) {
    event = event.copyWith(user: SentryUser(id: user.id, ipAddress: null));
  }
  return event;
}

Map<String, String>? _filterHeaders(Map<String, String>? headers) {
  if (headers == null) return null;
  const allowed = {'user-agent', 'x-request-id'};
  return {
    for (final entry in headers.entries)
      if (allowed.contains(entry.key.toLowerCase())) entry.key: entry.value,
  };
}

/// Convenience wrapper used by other services to drop a breadcrumb when
/// Sentry is configured (no-op otherwise).
Future<void> sentryBreadcrumb(
  String message, {
  String category = 'app',
  Map<String, Object?>? data,
}) async {
  if (!_isInitialized) return;
  await Sentry.addBreadcrumb(
    Breadcrumb(
      message: message,
      category: category,
      // Sentry's Breadcrumb wants Map<String,Object?>, which our typing
      // already provides.
      data: data,
    ),
  );
}

bool get _isInitialized {
  // Sentry exposes no public "is initialized" — but `Hub.isEnabled` does
  // the work. We tolerate the SDK throwing in tests by guarding via try.
  try {
    return Sentry.isEnabled;
  } on Object catch (_) {
    return false;
  }
}

/// Capture a typed exception. Used by the analyze flow + auth flow when
/// they hit unexpected failures and want forensic data in Sentry.
Future<void> sentryCapture(
  Object error,
  StackTrace? stack, {
  Map<String, Object?>? tags,
}) async {
  if (!_isInitialized) return;
  await Sentry.captureException(
    error,
    stackTrace: stack,
    withScope: (scope) {
      if (tags != null) {
        for (final t in tags.entries) {
          scope.setTag(t.key, t.value?.toString() ?? '');
        }
      }
    },
  );
}

@visibleForTesting
SentryEvent? scrubForTest(SentryEvent event) {
  // Hint() requires no args in modern SDKs; if the constructor changes,
  // we adjust here in one place.
  final result = _scrub(event, Hint());
  if (result is Future<SentryEvent?>) {
    throw StateError('scrubForTest expected a synchronous result');
  }
  return result;
}
