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
import '../../shared/services/image_service.dart';
import '../../shared/services/logger.dart';
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
  }) : _images = imageService,
       _storage = storageService,
       _analyze = analyzeService,
       _auth = authStatus,
       _analytics = analyticsService,
       super(const AnalysisIdle());

  final ImageService _images;
  final StorageService _storage;
  final AnalyzeService _analyze;
  final AuthStatus _auth;
  final AnalyticsService _analytics;

  static final _log = AppLogger.of('analysis.controller');

  PickedImage? _pendingImage;
  bool _submitting = false;

  /// User taps "Take photo" or "Pick image."
  Future<void> pickImage({required bool fromCamera}) async {
    if (_submitting) return;
    state = const AnalysisPreparing(null);
    try {
      final picked = fromCamera
          ? await _images.captureFromCamera()
          : await _images.pickFromGallery();
      if (picked == null) {
        state = const AnalysisIdle();
        return;
      }
      _pendingImage = picked;
      state = AnalysisPreparing(picked);
    } on ImagePickFailure catch (e) {
      _log.warning('image_pick_failed', e.message);
      state = AnalysisFailedState(AnalyzeFailureKind.validation, e.message);
    }
  }

  void clearImage() {
    _pendingImage = null;
    state = const AnalysisIdle();
  }

  /// Submit analyze. [text] is optional and complements the image; if
  /// only text is provided we send an `input_type=text` analysis.
  Future<void> submit({required Pet pet, String? text}) async {
    if (_submitting) return;
    final auth = _auth;
    if (auth is! Authenticated) {
      state = const AnalysisFailedState(
        AnalyzeFailureKind.unauthorized,
        'Please sign in again.',
      );
      return;
    }
    final userId = auth.user.id;

    final image = _pendingImage;
    final hasText = text != null && text.trim().isNotEmpty;
    if (image == null && !hasText) {
      state = const AnalysisFailedState(
        AnalyzeFailureKind.validation,
        'Add a photo or describe what you saw.',
      );
      return;
    }

    _submitting = true;
    final inputType = image != null ? 'photo' : 'text';
    final analyzeStart = DateTime.now();
    try {
      String? storageKey;
      if (image != null) {
        state = const AnalysisUploading();
        unawaited(
          _analytics.track(UploadStartedEvent(inputType: inputType)),
        );
        final uploadStart = DateTime.now();
        storageKey = await _storage.uploadPetImage(
          userId: userId,
          image: image,
        );
        unawaited(
          _analytics.track(
            UploadCompletedEvent(
              durationMs: DateTime.now().difference(uploadStart).inMilliseconds,
            ),
          ),
        );
      }

      state = const AnalysisAnalysing();
      unawaited(
        _analytics.track(AnalysisRequestedEvent(inputType: inputType)),
      );
      final result = await _analyze.submit(
        pet: pet,
        inputType: inputType,
        inputStorageKey: storageKey,
        textDescription: text,
      );
      state = AnalysisSuccess(result);
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
    } on StorageUploadFailure catch (e) {
      _log.warning('upload_failed', e.message);
      state = AnalysisFailedState(AnalyzeFailureKind.validation, e.message);
      unawaited(
        _analytics.track(
          AnalysisFailedEvent(kind: AnalyzeFailureKind.validation.name),
        ),
      );
    } on AnalyzeFailure catch (e) {
      _log.warning('analyze_failed', e.kind.name);
      state = AnalysisFailedState(e.kind, e.detail ?? e.kind.userMessage);
      unawaited(_analytics.track(AnalysisFailedEvent(kind: e.kind.name)));
    } on Object catch (e, s) {
      _log.severe('analyze_unexpected', e, s);
      state = AnalysisFailedState(
        AnalyzeFailureKind.unknown,
        AnalyzeFailureKind.unknown.userMessage,
      );
      unawaited(
        _analytics.track(
          AnalysisFailedEvent(kind: AnalyzeFailureKind.unknown.name),
        ),
      );
    } finally {
      _submitting = false;
    }
  }

  void reset() {
    _pendingImage = null;
    _submitting = false;
    state = const AnalysisIdle();
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
      );
      ref.onDispose(controller.reset);
      return controller;
    });
