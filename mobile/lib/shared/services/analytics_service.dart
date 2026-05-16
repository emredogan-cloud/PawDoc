/// Product analytics — centralised PostHog facade.
///
/// Discipline:
///   - Widgets MUST NOT import `posthog_flutter` directly. Every
///     analytics call is routed through [AnalyticsService].
///   - Controllers emit typed [AnalyticsEvent] values; the service
///     handles SDK conversion + PII filtering.
///   - Failure modes are always silent. `track` is fire-and-forget; init
///     failures degrade to a no-op service so the boot path stays green.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../../app/config.dart';
import 'analytics_events.dart';
import 'logger.dart';

/// Interface — the only type widget/controller code should ever see.
abstract class AnalyticsService {
  Future<void> initialize();
  Future<void> identify(String userId);
  Future<void> resetIdentity();
  Future<void> track(AnalyticsEvent event);
}

/// Real PostHog implementation. Wraps `Posthog()` so callers don't see
/// the SDK class.
class PostHogAnalyticsService implements AnalyticsService {
  PostHogAnalyticsService({
    required String apiKey,
    required String host,
    PostHogConfig? configOverride,
    Posthog? clientOverride,
  }) : _apiKey = apiKey,
       _host = host,
       _configOverride = configOverride,
       _client = clientOverride ?? Posthog();

  final String _apiKey;
  final String _host;
  final PostHogConfig? _configOverride;
  final Posthog _client;
  bool _initialized = false;

  static final _log = AppLogger.of('analytics.posthog');

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final config = _configOverride ?? (PostHogConfig(_apiKey)..host = _host);
      await _client.setup(config);
      _initialized = true;
      _log.info('analytics_initialized', _host);
    } on Object catch (e, s) {
      // Init failures are non-fatal: the wider boot path uses a noop
      // service from then on. We log + swallow.
      _log.warning('analytics_init_failed', e);
      AppLogger.of('analytics.posthog').severe('init_failed', e, s);
      _initialized = false;
    }
  }

  @override
  Future<void> identify(String userId) async {
    if (!_initialized) return;
    try {
      await _client.identify(userId: userId);
    } on Object catch (e) {
      _log.warning('identify_failed', e);
    }
  }

  @override
  Future<void> resetIdentity() async {
    if (!_initialized) return;
    try {
      await _client.reset();
    } on Object catch (e) {
      _log.warning('reset_failed', e);
    }
  }

  @override
  Future<void> track(AnalyticsEvent event) async {
    if (!_initialized) return;
    try {
      final props = _stripNulls(event.properties);
      await _client.capture(
        eventName: event.name,
        properties: props.isEmpty ? null : props,
      );
    } on Object catch (e) {
      _log.warning('capture_failed', '${event.name}: $e');
    }
  }

  /// PostHog's capture API rejects null-valued entries on some
  /// platforms. We drop them at the boundary so call sites can pass
  /// nullable values without ceremony.
  Map<String, Object> _stripNulls(Map<String, Object?> input) {
    final out = <String, Object>{};
    for (final entry in input.entries) {
      final v = entry.value;
      if (v != null) out[entry.key] = v;
    }
    return out;
  }
}

/// Used when PostHog is not configured (e.g. local dev with no key, or
/// after a failed initialise) and in unit tests.
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> identify(String userId) async {}
  @override
  Future<void> resetIdentity() async {}
  @override
  Future<void> track(AnalyticsEvent event) async {}
}

/// Test-only service that records every interaction in memory so tests
/// can assert on order, count, and properties without a real PostHog
/// project.
@visibleForTesting
class RecordingAnalyticsService implements AnalyticsService {
  final List<AnalyticsEvent> trackedEvents = [];
  final List<String> identified = [];
  int resetCount = 0;
  bool initialised = false;

  @override
  Future<void> initialize() async {
    initialised = true;
  }

  @override
  Future<void> identify(String userId) async {
    identified.add(userId);
  }

  @override
  Future<void> resetIdentity() async {
    resetCount += 1;
  }

  @override
  Future<void> track(AnalyticsEvent event) async {
    trackedEvents.add(event);
  }
}

/// Riverpod surface. Overridden in tests; the default reads the
/// `appConfigProvider` and constructs PostHog/Noop accordingly.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasPosthog) {
    return const NoopAnalyticsService();
  }
  return PostHogAnalyticsService(
    apiKey: config.posthogApiKey,
    host: config.posthogHost,
  );
});
