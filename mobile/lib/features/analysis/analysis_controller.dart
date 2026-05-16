/// Analysis flow controller.
///
/// Tracks the entire user-visible state machine for a single analyze
/// attempt: picking media, compressing, uploading, sending to the edge
/// function, rendering the result.
///
/// Phase 1C explicitly does NOT mix concerns across attempts. Each
/// invocation of [submit] either succeeds with a result or fails with a
/// typed reason; the controller resets to [AnalysisIdle] when the user
/// leaves the screen.
///
/// Sprint B1 reliability discipline:
///   - Every `submit()` assigns a fresh `_currentAttemptId`. Late
///     callbacks (success / failure handlers that fire after
///     dispose, retry, or abort) verify the id before mutating state.
///   - Successful uploads are cached against the `PickedImage`
///     instance: retrying the same analysis reuses the storage key,
///     preventing duplicate uploads and a second quota consume.
///   - Offline pre-flight via `ConnectivityService` short-circuits
///     before any HTTP — no spurious quota burn when the user is on
///     airplane mode.
///   - `_disposed` gates every state write after an `await` so the
///     `autoDispose` semantics never raise a "modified after dispose"
///     in tests or in release.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/analysis_result.dart';
import '../../shared/models/pet.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/analytics_events.dart';
import '../../shared/services/analytics_service.dart';
import '../../shared/services/analyze_service.dart';
import '../../shared/services/connectivity_service.dart';
import '../../shared/services/image_service.dart';
import '../../shared/services/logger.dart';
import '../../shared/services/sentry_service.dart';
import '../../shared/services/storage_service.dart';

@immutable
sealed class AnalysisState {
  const AnalysisState();
}

class AnalysisIdle extends AnalysisState {
  const AnalysisIdle();
}

class AnalysisPreparing extends AnalysisState {
  const AnalysisPreparing(this.image);
  final PickedImage? image;
}

class AnalysisUploading extends AnalysisState {
  const AnalysisUploading();
}

class AnalysisAnalysing extends AnalysisState {
  const AnalysisAnalysing();
}

class AnalysisSuccess extends AnalysisState {
  const AnalysisSuccess(this.result);
  final AnalysisResult result;
}

class AnalysisFailedState extends AnalysisState {
  const AnalysisFailedState(this.kind, this.message);
  final AnalyzeFailureKind kind;
  final String message;
}

class AnalysisController extends StateNotifier<AnalysisState> {
  AnalysisController({
    required ImageService imageService,
    required StorageService storageService,
    required AnalyzeService analyzeService,
    required AuthStatus authStatus,
    required AnalyticsService analyticsService,
    required ConnectivityService connectivity,
  }) : _images = imageService,
       _storage = storageService,
       _analyze = analyzeService,
       _auth = authStatus,
       _analytics = analyticsService,
       _connectivity = connectivity,
       super(const AnalysisIdle());

  final ImageService _images;
  final StorageService _storage;
  final AnalyzeService _analyze;
  final AuthStatus _auth;
  final AnalyticsService _analytics;
  final ConnectivityService _connectivity;

  static final _log = AppLogger.of('analysis.controller');

  PickedImage? _pendingImage;
  // Storage key from a successful upload, paired with the image
  // identity it was uploaded under. Retrying the same image short-
  // circuits the upload step; picking a new image clears the cache.
  PickedImage? _cachedUploadFor;
  String? _cachedStorageKey;

  bool _submitting = false;
  int _attemptIdSeq = 0;
  // Identifier of the in-flight submission. State writes after an
  // `await` check this against the current value before mutating —
  // late callbacks from a superseded attempt are dropped silently.
  int? _currentAttemptId;
  bool _disposed = false;

  /// True when a submit is in flight. The UI uses this to grey out
  /// the Analyze button between the tap and the first state
  /// transition, eliminating the 1-frame double-tap race.
  bool get isBusy => _submitting;

  /// Override visibility hook — the autoDispose provider calls
  /// `reset()` on dispose; we additionally set `_disposed` so late
  /// callbacks abandon their state writes.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Apply a new state, but only if the controller hasn't been
  /// disposed and the attempt id (if supplied) still matches the
  /// in-flight one. All async branches MUST route their writes
  /// through this — direct `state = …` is a foot-gun.
  void _writeState(AnalysisState next, {int? attemptId}) {
    if (_disposed) return;
    if (attemptId != null && attemptId != _currentAttemptId) return;
    state = next;
  }

  /// User taps "Take photo" or "Pick image."
  Future<void> pickImage({required bool fromCamera}) async {
    if (_submitting) return;
    _writeState(const AnalysisPreparing(null));
    try {
      final picked = fromCamera
          ? await _images.captureFromCamera()
          : await _images.pickFromGallery();
      if (_disposed) return;
      if (picked == null) {
        _writeState(const AnalysisIdle());
        return;
      }
      _pendingImage = picked;
      // Picking a fresh image invalidates any cached upload.
      _cachedUploadFor = null;
      _cachedStorageKey = null;
      _writeState(AnalysisPreparing(picked));
    } on ImagePickFailure catch (e) {
      _log.warning('image_pick_failed', '${e.kind.name}: ${e.message}');
      final kind = _mapImagePickFailure(e.kind);
      _writeState(AnalysisFailedState(kind, e.message));
      unawaited(_analytics.track(AnalysisFailedEvent(kind: kind.name)));
    }
  }

  /// Image-pick failures from [ImageServiceImpl] are split into typed
  /// `AnalyzeFailureKind` buckets so analytics + UX can branch.
  AnalyzeFailureKind _mapImagePickFailure(ImagePickFailureKind kind) =>
      switch (kind) {
        ImagePickFailureKind.empty ||
        ImagePickFailureKind.unsupportedFormat ||
        ImagePickFailureKind.tooSmall ||
        ImagePickFailureKind.tooLarge ||
        ImagePickFailureKind.oversized ||
        ImagePickFailureKind.compressionFailed =>
          AnalyzeFailureKind.unsupportedImage,
        ImagePickFailureKind.permissionDenied => AnalyzeFailureKind.validation,
        ImagePickFailureKind.unknown => AnalyzeFailureKind.validation,
      };

  void clearImage() {
    _pendingImage = null;
    _cachedUploadFor = null;
    _cachedStorageKey = null;
    _writeState(const AnalysisIdle());
  }

  /// Submit analyze. [text] is optional and complements the image; if
  /// only text is provided we send an `input_type=text` analysis.
  Future<void> submit({required Pet pet, String? text}) async {
    if (_submitting || _disposed) return;
    final auth = _auth;
    if (auth is! Authenticated) {
      _writeState(
        const AnalysisFailedState(
          AnalyzeFailureKind.unauthorized,
          'Please sign in again.',
        ),
      );
      return;
    }
    final userId = auth.user.id;

    final image = _pendingImage;
    final hasText = text != null && text.trim().isNotEmpty;
    if (image == null && !hasText) {
      _writeState(
        const AnalysisFailedState(
          AnalyzeFailureKind.validation,
          'Add a photo or describe what you saw.',
        ),
      );
      return;
    }

    // Claim the slot synchronously so a double-tap that fires before
    // any `await` yields still sees `isBusy == true` on the second
    // call. This closes the 1-frame race window where the offline
    // pre-flight's microtask let a second `submit()` slip through.
    _submitting = true;
    final attemptId = ++_attemptIdSeq;
    _currentAttemptId = attemptId;
    final inputType = image != null ? 'photo' : 'text';
    final analyzeStart = DateTime.now();
    // Sprint B3 (F-OPS5): journey breadcrumb so crash reports contain
    // what the user was doing. No PII — just the typed input kind.
    unawaited(
      sentryBreadcrumb(
        'analyze_submit',
        category: 'analyze',
        data: {'input_type': inputType, 'attempt_id': attemptId},
      ),
    );
    try {
      // Offline pre-flight — fail fast before consuming any quota or
      // creating a storage object. We use the cached value (non-blocking
      // when possible) so the user gets immediate feedback.
      if (!await _connectivity.isOnline()) {
        if (_disposed) return;
        _writeState(
          AnalysisFailedState(
            AnalyzeFailureKind.offline,
            AnalyzeFailureKind.offline.userMessage,
          ),
          attemptId: attemptId,
        );
        unawaited(
          _analytics.track(
            AnalysisFailedEvent(kind: AnalyzeFailureKind.offline.name),
          ),
        );
        return;
      }
      String? storageKey;
      if (image != null) {
        // Reuse the cached upload from a previous failed attempt on
        // the same image. This is the single most important quota
        // + orphan-bytes guard: a user mashing the retry button never
        // creates more than one storage object per picked photo.
        if (_cachedStorageKey != null &&
            identical(_cachedUploadFor, image)) {
          storageKey = _cachedStorageKey;
          _log.info('upload_reused_cache', storageKey);
        } else {
          _writeState(const AnalysisUploading(), attemptId: attemptId);
          unawaited(
            _analytics.track(UploadStartedEvent(inputType: inputType)),
          );
          final uploadStart = DateTime.now();
          storageKey = await _storage.uploadPetImage(
            userId: userId,
            image: image,
          );
          if (_disposed || attemptId != _currentAttemptId) return;
          _cachedUploadFor = image;
          _cachedStorageKey = storageKey;
          unawaited(
            _analytics.track(
              UploadCompletedEvent(
                durationMs: DateTime.now()
                    .difference(uploadStart)
                    .inMilliseconds,
              ),
            ),
          );
        }
      }

      _writeState(const AnalysisAnalysing(), attemptId: attemptId);
      unawaited(
        _analytics.track(AnalysisRequestedEvent(inputType: inputType)),
      );
      final result = await _analyze.submit(
        pet: pet,
        inputType: inputType,
        inputStorageKey: storageKey,
        textDescription: text,
      );
      if (_disposed || attemptId != _currentAttemptId) return;
      _writeState(AnalysisSuccess(result), attemptId: attemptId);
      // A successful analysis consumes the cached image — retrying
      // would shadow the analyses row that's now persisted.
      _cachedUploadFor = null;
      _cachedStorageKey = null;
      _log.info('analyze_done', result.triageLevel.name);
      final latencyMs = DateTime.now()
          .difference(analyzeStart)
          .inMilliseconds;
      unawaited(
        _analytics.track(
          AnalysisCompletedEvent(
            triageLevel: result.triageLevel.name.toUpperCase(),
            tierUsed: result.tierUsed,
            latencyMs: latencyMs,
          ),
        ),
      );
      if (result.triageLevel.name.toUpperCase() == 'EMERGENCY') {
        unawaited(_analytics.track(const EmergencyResultSeenEvent()));
      }
    } on StorageUploadInterrupted catch (e) {
      _log.warning('upload_interrupted', e.message);
      _writeState(
        AnalysisFailedState(
          AnalyzeFailureKind.uploadInterrupted,
          AnalyzeFailureKind.uploadInterrupted.userMessage,
        ),
        attemptId: attemptId,
      );
      unawaited(
        _analytics.track(
          AnalysisFailedEvent(
            kind: AnalyzeFailureKind.uploadInterrupted.name,
          ),
        ),
      );
      unawaited(
        sentryBreadcrumb(
          'analyze_failed',
          category: 'analyze',
          data: {'kind': AnalyzeFailureKind.uploadInterrupted.name},
        ),
      );
    } on StorageUploadFailure catch (e) {
      _log.warning('upload_failed', e.message);
      _writeState(
        AnalysisFailedState(AnalyzeFailureKind.validation, e.message),
        attemptId: attemptId,
      );
      unawaited(
        _analytics.track(
          AnalysisFailedEvent(kind: AnalyzeFailureKind.validation.name),
        ),
      );
      unawaited(
        sentryBreadcrumb(
          'analyze_failed',
          category: 'analyze',
          data: {'kind': AnalyzeFailureKind.validation.name},
        ),
      );
    } on AnalyzeFailure catch (e) {
      _log.warning('analyze_failed', e.kind.name);
      _writeState(
        AnalysisFailedState(e.kind, e.detail ?? e.kind.userMessage),
        attemptId: attemptId,
      );
      unawaited(_analytics.track(AnalysisFailedEvent(kind: e.kind.name)));
      unawaited(
        sentryBreadcrumb(
          'analyze_failed',
          category: 'analyze',
          data: {'kind': e.kind.name},
        ),
      );
    } on Object catch (e, s) {
      _log.severe('analyze_unexpected', e, s);
      _writeState(
        AnalysisFailedState(
          AnalyzeFailureKind.unknown,
          AnalyzeFailureKind.unknown.userMessage,
        ),
        attemptId: attemptId,
      );
      unawaited(
        _analytics.track(
          AnalysisFailedEvent(kind: AnalyzeFailureKind.unknown.name),
        ),
      );
      unawaited(
        sentryBreadcrumb(
          'analyze_failed',
          category: 'analyze',
          data: {'kind': AnalyzeFailureKind.unknown.name},
        ),
      );
      // Programmer bugs hide as `.unknown` in release. In debug we
      // re-throw so they surface in the test output / hot-restart
      // console instead of being silently swallowed.
      if (kDebugMode) rethrow;
    } finally {
      if (attemptId == _currentAttemptId) {
        _submitting = false;
      }
    }
  }

  /// Lifecycle hook: app resumed after a long idle and the controller
  /// is still wedged in a loading state. Map it to a friendly
  /// "connection was lost" failure so the user can retry, and
  /// invalidate the in-flight attempt id so any late callbacks from
  /// the stranded HTTP request silently discard their writes.
  ///
  /// Called from `_AppLifecycleObserver._maybeRefreshOnResume`.
  void notifyResumedAfterLongIdle() {
    final s = state;
    if (s is AnalysisUploading || s is AnalysisAnalysing) {
      _log.info('analysis_recovered_from_background', s.runtimeType.toString());
      // Invalidate the in-flight attempt so the original `submit`'s
      // late state writes are dropped by `_writeState`.
      _currentAttemptId = null;
      _submitting = false;
      _writeState(
        AnalysisFailedState(
          AnalyzeFailureKind.uploadInterrupted,
          AnalyzeFailureKind.uploadInterrupted.userMessage,
        ),
      );
      unawaited(
        _analytics.track(
          AnalysisFailedEvent(
            kind: AnalyzeFailureKind.uploadInterrupted.name,
          ),
        ),
      );
    }
  }

  void reset() {
    _pendingImage = null;
    _cachedUploadFor = null;
    _cachedStorageKey = null;
    _submitting = false;
    _currentAttemptId = null;
    if (!_disposed) state = const AnalysisIdle();
  }
}

/// The .autoDispose factory wires Ref.onDispose so a user backing out of
/// the analyze screen mid-call cancels any in-flight work. The state
/// notifier itself is not cancellable, but its `_submitting` flag
/// prevents double-fire and the surrounding controller is recreated when
/// the user returns.
final analysisControllerProvider =
    StateNotifierProvider.autoDispose<AnalysisController, AnalysisState>((ref) {
      final controller = AnalysisController(
        imageService: ref.watch(imageServiceProvider),
        storageService: ref.watch(storageServiceProvider),
        analyzeService: ref.watch(analyzeServiceProvider),
        authStatus: ref.watch(authStateProvider),
        analyticsService: ref.watch(analyticsServiceProvider),
        connectivity: ref.watch(connectivityServiceProvider),
      );
      ref.onDispose(controller.reset);
      return controller;
    });
