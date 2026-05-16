/// Online / offline detection.
///
/// Wraps `connectivity_plus` so the rest of the app never imports the
/// SDK directly. Two surfaces:
///
///   - `onlineChanges` — broadcast `bool` stream (true = at least one
///     network interface up). Always emits the initial state once on
///     subscribe.
///   - `isOnline()` — one-shot pre-flight, used by the analyze
///     controller to fail fast.
///
/// The "online" boolean is a *deliberate* simplification of
/// `ConnectivityResult`: any of {wifi, mobile, ethernet, vpn,
/// bluetooth, satellite, other} counts as online, only `none` counts
/// as offline. We don't care which interface is up — the AI service
/// is on the public internet either way.
///
/// IMPORTANT: this service tells us if the device *has* a network
/// route — it does NOT tell us if the route works (captive portals,
/// DNS poisoning, ISP-level filtering all report "online"). The
/// analyze flow still relies on a request timeout to catch those.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logger.dart';

abstract class ConnectivityService {
  Stream<bool> get onlineChanges;
  Future<bool> isOnline();
}

class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged
        .map(_isOnline)
        .listen(_onChange, onError: _onError);
    // Seed the controller with the initial state so subscribers don't
    // have to wait for the first interface change.
    unawaited(_seedInitial());
  }

  final Connectivity _connectivity;
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  StreamSubscription<bool>? _subscription;
  bool? _last;
  bool _disposed = false;

  static final _log = AppLogger.of('connectivity');

  Future<void> _seedInitial() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _onChange(_isOnline(results));
    } on Object catch (e) {
      // Plugin can throw on early-init on some hosts. Default to
      // assuming we're online so we never block real users behind a
      // false-negative pre-flight.
      _log.warning('connectivity_check_failed', e);
      _onChange(true);
    }
  }

  void _onChange(bool online) {
    if (_disposed) return;
    if (_last == online) return;
    _last = online;
    _controller.add(online);
  }

  void _onError(Object error, StackTrace stack) {
    _log.warning('connectivity_stream_error', error);
    // Stream errors should not flip the user offline; failing open is
    // the safer default. We do not propagate the error downstream.
  }

  static bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return !(results.length == 1 && results.first == ConnectivityResult.none);
  }

  @override
  Stream<bool> get onlineChanges async* {
    // Replay the most recent value to new subscribers, then forward.
    if (_last != null) yield _last!;
    yield* _controller.stream;
  }

  @override
  Future<bool> isOnline() async {
    if (_last != null) return _last!;
    try {
      final results = await _connectivity.checkConnectivity();
      return _isOnline(results);
    } on Object catch (e) {
      _log.warning('connectivity_isonline_failed', e);
      // Fail open: we'd rather attempt and get a typed network error
      // than block a user whose plugin instance just hiccuped.
      return true;
    }
  }

  @visibleForTesting
  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await _controller.close();
  }
}

/// Always-online stub for tests + when the platform plugin isn't
/// available (e.g. headless CI).
class AlwaysOnlineConnectivityService implements ConnectivityService {
  const AlwaysOnlineConnectivityService();
  @override
  Stream<bool> get onlineChanges => Stream<bool>.value(true);
  @override
  Future<bool> isOnline() async => true;
}

/// Test seam — drives the stream + `isOnline()` from a single
/// in-memory boolean so chaos tests can flip the user offline.
@visibleForTesting
class RecordingConnectivityService implements ConnectivityService {
  RecordingConnectivityService({bool initiallyOnline = true})
    : _online = initiallyOnline {
    _controller.add(initiallyOnline);
  }

  bool _online;
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Stream<bool> get onlineChanges async* {
    yield _online;
    yield* _controller.stream;
  }

  @override
  Future<bool> isOnline() async => _online;

  Future<void> dispose() => _controller.close();
}

/// Cached singleton. The implementation owns a stream subscription; we
/// don't want to spin up a new one per `ref.watch`.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityServiceImpl();
  // Note: we deliberately don't dispose this on container teardown —
  // it's a process-wide singleton tracked by the platform plugin.
  return service;
});

/// Boolean view over the service for widgets + controllers. Defaults
/// to `true` (online) on the very first read so the UI doesn't
/// flicker an offline banner during boot.
final connectivityProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onlineChanges;
});
