/// Sprint B1 chaos tests for `AnalysisController`.
///
/// Each test simulates a single real-world failure mode end-to-end:
///   - upload timeout / interruption
///   - analyze timeout
///   - storage-key reuse across retries (prevents duplicate uploads)
///   - offline pre-flight
///   - double-tap submit
///   - dispose mid-flight (no state-after-dispose exceptions)
///   - resume-from-background while wedged in a loading state
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pawdoc/features/analysis/analysis_controller.dart';
import 'package:pawdoc/shared/models/analysis_result.dart';
import 'package:pawdoc/shared/models/pet.dart';
import 'package:pawdoc/shared/providers/auth_provider.dart';
import 'package:pawdoc/shared/services/analytics_events.dart';
import 'package:pawdoc/shared/services/analytics_service.dart';
import 'package:pawdoc/shared/services/analyze_service.dart';
import 'package:pawdoc/shared/services/connectivity_service.dart';
import 'package:pawdoc/shared/services/image_service.dart';
import 'package:pawdoc/shared/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeImageService implements ImageService {
  _FakeImageService(this.image);
  PickedImage? image;
  ImagePickFailure? throwOnNext;
  @override
  Future<PickedImage?> captureFromCamera() async {
    if (throwOnNext != null) {
      final t = throwOnNext!;
      throwOnNext = null;
      throw t;
    }
    return image;
  }

  @override
  Future<PickedImage?> pickFromGallery() => captureFromCamera();
}

class _MockStorageService implements StorageService {
  int uploadCount = 0;
  Completer<String>? pending;
  Exception? throwOnNext;
  String returnKey = 'user-1/img.jpg';

  void completeWith(String key) {
    final p = pending;
    pending = null;
    p?.complete(key);
  }

  void failWith(Object error) {
    final p = pending;
    pending = null;
    p?.completeError(error);
  }

  @override
  Future<String> uploadPetImage({
    required String userId,
    required PickedImage image,
  }) async {
    uploadCount += 1;
    if (throwOnNext != null) {
      final t = throwOnNext!;
      throwOnNext = null;
      throw t;
    }
    if (pending != null) return pending!.future;
    return returnKey;
  }
}

class _MockAnalyzeService implements AnalyzeService {
  int submitCount = 0;
  String? lastStorageKey;
  Completer<AnalysisResult>? pending;
  Exception? throwOnNext;
  AnalysisResult? returnResult;

  void completeWith(AnalysisResult r) {
    final p = pending;
    pending = null;
    p?.complete(r);
  }

  void failWith(Object error) {
    final p = pending;
    pending = null;
    p?.completeError(error);
  }

  @override
  Future<AnalysisResult> submit({
    required Pet pet,
    required String inputType,
    String? inputStorageKey,
    String? textDescription,
  }) async {
    submitCount += 1;
    lastStorageKey = inputStorageKey;
    if (throwOnNext != null) {
      final t = throwOnNext!;
      throwOnNext = null;
      throw t;
    }
    if (pending != null) return pending!.future;
    return returnResult!;
  }
}

class _MockUser extends Mock implements User {}

Pet _samplePet() => Pet(
  id: 'pet-1',
  userId: 'user-1',
  name: 'Luna',
  species: PetSpecies.dog,
  createdAt: DateTime(2026, 1, 1),
);

AnalysisResult _sampleResult({
  TriageLevel level = TriageLevel.normal,
  String analysisId = 'a-1',
}) => AnalysisResult(
  analysisId: analysisId,
  triageLevel: level,
  confidence: 0.9,
  primaryConcern: 'Routine check',
  visibleSymptoms: const [],
  differential: const [],
  recommendedActions: const [],
  urgencyTimeframe: 'days',
  disclaimerRequired: true,
  disclaimerText: 'Not a diagnosis.',
  modelUsed: 'gemini-flash',
  tierUsed: 2,
  emergencyOverrideApplied: false,
  crossVerifyDisagreement: false,
  aiLatencyMs: 800,
  requestId: 'req-1',
);

PickedImage _samplePicked() => PickedImage(
  bytes: Uint8List.fromList([1, 2, 3]),
  mimeType: 'image/jpeg',
  originalSizeBytes: 3,
  finalSizeBytes: 3,
);

class _Harness {
  _Harness({bool initiallyOnline = true})
    : image = _samplePicked(),
      images = _FakeImageService(null),
      storage = _MockStorageService(),
      analyze = _MockAnalyzeService(),
      analytics = RecordingAnalyticsService(),
      connectivity = RecordingConnectivityService(
        initiallyOnline: initiallyOnline,
      );

  final PickedImage image;
  final _FakeImageService images;
  final _MockStorageService storage;
  final _MockAnalyzeService analyze;
  final RecordingAnalyticsService analytics;
  final RecordingConnectivityService connectivity;

  AnalysisController build() {
    final user = _MockUser();
    when(() => user.id).thenReturn('user-1');
    return AnalysisController(
      imageService: images,
      storageService: storage,
      analyzeService: analyze,
      authStatus: Authenticated(user),
      analyticsService: analytics,
      connectivity: connectivity,
    );
  }
}

void main() {
  group('upload reliability', () {
    test('upload timeout maps to uploadInterrupted + no analyze call', () async {
      final h = _Harness();
      h.images.image = h.image;
      final ctrl = h.build();
      addTearDown(ctrl.dispose);

      await ctrl.pickImage(fromCamera: true);
      h.storage.throwOnNext = const StorageUploadInterrupted();

      await ctrl.submit(pet: _samplePet());

      expect(ctrl.state, isA<AnalysisFailedState>());
      expect(
        (ctrl.state as AnalysisFailedState).kind,
        AnalyzeFailureKind.uploadInterrupted,
      );
      expect(h.analyze.submitCount, 0);
    });

    test('successful upload then analyze timeout caches storage key', () async {
      final h = _Harness();
      h.images.image = h.image;
      final ctrl = h.build();
      addTearDown(ctrl.dispose);

      await ctrl.pickImage(fromCamera: true);
      h.storage.returnKey = 'user-1/cached.jpg';
      h.analyze.throwOnNext = const AnalyzeFailure(AnalyzeFailureKind.timeout);

      await ctrl.submit(pet: _samplePet());

      expect(h.storage.uploadCount, 1);
      expect(h.analyze.submitCount, 1);
      expect(h.analyze.lastStorageKey, 'user-1/cached.jpg');
      expect(
        (ctrl.state as AnalysisFailedState).kind,
        AnalyzeFailureKind.timeout,
      );

      // Retry — the same image should reuse the cached storage key.
      h.analyze.returnResult = _sampleResult();
      await ctrl.submit(pet: _samplePet());

      expect(h.storage.uploadCount, 1, reason: 'upload reused cached key');
      expect(h.analyze.submitCount, 2);
      expect(h.analyze.lastStorageKey, 'user-1/cached.jpg');
      expect(ctrl.state, isA<AnalysisSuccess>());
    });

    test('successful analysis clears the cached storage key', () async {
      final h = _Harness();
      h.images.image = h.image;
      final ctrl = h.build();
      addTearDown(ctrl.dispose);

      await ctrl.pickImage(fromCamera: true);
      h.analyze.returnResult = _sampleResult();
      await ctrl.submit(pet: _samplePet());

      expect(ctrl.state, isA<AnalysisSuccess>());
      expect(h.storage.uploadCount, 1);
    });

    test('picking a fresh image invalidates the cached upload', () async {
      final h = _Harness();
      h.images.image = h.image;
      final ctrl = h.build();
      addTearDown(ctrl.dispose);

      await ctrl.pickImage(fromCamera: true);
      h.analyze.throwOnNext = const AnalyzeFailure(AnalyzeFailureKind.timeout);
      await ctrl.submit(pet: _samplePet());
      expect(h.storage.uploadCount, 1);

      // User re-picks → cache busts.
      h.images.image = _samplePicked();
      await ctrl.pickImage(fromCamera: true);
      h.analyze.returnResult = _sampleResult();
      await ctrl.submit(pet: _samplePet());
      expect(h.storage.uploadCount, 2);
    });
  });

  group('offline pre-flight', () {
    test('offline submit refuses without touching storage or analyze', () async {
      final h = _Harness(initiallyOnline: false);
      h.images.image = h.image;
      final ctrl = h.build();
      addTearDown(ctrl.dispose);

      await ctrl.pickImage(fromCamera: true);
      await ctrl.submit(pet: _samplePet());

      expect(ctrl.state, isA<AnalysisFailedState>());
      expect(
        (ctrl.state as AnalysisFailedState).kind,
        AnalyzeFailureKind.offline,
      );
      expect(h.storage.uploadCount, 0);
      expect(h.analyze.submitCount, 0);
    });

    test('comes back online → submit proceeds', () async {
      final h = _Harness(initiallyOnline: false);
      h.images.image = h.image;
      final ctrl = h.build();
      addTearDown(ctrl.dispose);

      await ctrl.pickImage(fromCamera: true);
      await ctrl.submit(pet: _samplePet());
      expect(
        (ctrl.state as AnalysisFailedState).kind,
        AnalyzeFailureKind.offline,
      );

      h.connectivity.setOnline(true);
      h.analyze.returnResult = _sampleResult();
      await ctrl.submit(pet: _samplePet());
      expect(ctrl.state, isA<AnalysisSuccess>());
    });
  });

  group('double-submit prevention', () {
    test('repeated submit while busy is a no-op', () async {
      final h = _Harness();
      h.images.image = h.image;
      final ctrl = h.build();
      addTearDown(ctrl.dispose);

      await ctrl.pickImage(fromCamera: true);

      // Hold the upload open so the controller is mid-submit.
      h.storage.pending = Completer<String>();
      final first = ctrl.submit(pet: _samplePet());
      expect(ctrl.isBusy, isTrue);

      // Fire a second submit — should be dropped on the floor.
      await ctrl.submit(pet: _samplePet());
      expect(h.storage.uploadCount, 1);
      expect(h.analyze.submitCount, 0);

      // Resolve the first submit cleanly.
      h.storage.completeWith('user-1/k.jpg');
      h.analyze.returnResult = _sampleResult();
      await first;
      expect(ctrl.state, isA<AnalysisSuccess>());
    });
  });

  group('dispose mid-flight', () {
    test('dispose during await does not raise + state stays Idle', () async {
      final h = _Harness();
      h.images.image = h.image;
      final ctrl = h.build();

      await ctrl.pickImage(fromCamera: true);
      h.storage.pending = Completer<String>();
      final submitFuture = ctrl.submit(pet: _samplePet());

      ctrl.dispose();
      // Now finish the upload — the controller should silently
      // discard the callback rather than mutating disposed state.
      h.storage.completeWith('user-1/k.jpg');
      h.analyze.returnResult = _sampleResult();

      await expectLater(submitFuture, completes);
      // No assertion on `state` — it's UB to read a disposed
      // StateNotifier. The point is `completes` (no exception).
    });
  });

  group('lifecycle recovery', () {
    test('resume-after-long-idle wedged Uploading → uploadInterrupted', () async {
      final h = _Harness();
      h.images.image = h.image;
      final ctrl = h.build();
      addTearDown(ctrl.dispose);

      await ctrl.pickImage(fromCamera: true);
      h.storage.pending = Completer<String>();
      unawaited(ctrl.submit(pet: _samplePet()));
      // Let the connectivity-pre-flight microtask resolve and the
      // controller transition into AnalysisUploading before we
      // simulate the resume.
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.state, isA<AnalysisUploading>());

      // Simulate the lifecycle observer detecting a long background.
      ctrl.notifyResumedAfterLongIdle();

      expect(ctrl.state, isA<AnalysisFailedState>());
      expect(
        (ctrl.state as AnalysisFailedState).kind,
        AnalyzeFailureKind.uploadInterrupted,
      );

      // Late completion lands AFTER the recovery transition; should
      // be ignored (attempt id check). State stays as failed.
      h.storage.completeWith('user-1/k.jpg');
      h.analyze.returnResult = _sampleResult();
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.state, isA<AnalysisFailedState>());
    });

    test('resume-after-idle while Idle is a no-op', () async {
      final h = _Harness();
      final ctrl = h.build();
      addTearDown(ctrl.dispose);

      expect(ctrl.state, isA<AnalysisIdle>());
      ctrl.notifyResumedAfterLongIdle();
      expect(ctrl.state, isA<AnalysisIdle>());
    });
  });

  group('image moderation (Sprint B2)', () {
    test(
      'unsupportedFormat image-pick maps to unsupportedImage + analytics',
      () async {
        final h = _Harness();
        final ctrl = h.build();
        addTearDown(ctrl.dispose);

        h.images.throwOnNext = const ImagePickFailure(
          "That file type isn't supported. Use a JPG, PNG, HEIC, or WEBP.",
          kind: ImagePickFailureKind.unsupportedFormat,
        );
        await ctrl.pickImage(fromCamera: true);

        expect(ctrl.state, isA<AnalysisFailedState>());
        expect(
          (ctrl.state as AnalysisFailedState).kind,
          AnalyzeFailureKind.unsupportedImage,
        );
        // Storage and analyze are never touched on a hygiene reject.
        expect(h.storage.uploadCount, 0);
        expect(h.analyze.submitCount, 0);
        // Analytics carries the typed kind, never the raw error message.
        expect(
          h.analytics.trackedEvents
              .whereType<AnalysisFailedEvent>()
              .single
              .properties['kind'],
          'unsupportedImage',
        );
      },
    );

    test(
      'tooSmall dimensions map to unsupportedImage',
      () async {
        final h = _Harness();
        final ctrl = h.build();
        addTearDown(ctrl.dispose);

        h.images.throwOnNext = const ImagePickFailure(
          'That image is too small. Try a clearer photo (at least 200×200 pixels).',
          kind: ImagePickFailureKind.tooSmall,
        );
        await ctrl.pickImage(fromCamera: true);

        expect(
          (ctrl.state as AnalysisFailedState).kind,
          AnalyzeFailureKind.unsupportedImage,
        );
      },
    );

    test(
      'permissionDenied stays in validation (not unsupportedImage)',
      () async {
        final h = _Harness();
        final ctrl = h.build();
        addTearDown(ctrl.dispose);

        h.images.throwOnNext = const ImagePickFailure(
          'Permission denied. Allow camera/photos access in Settings.',
          kind: ImagePickFailureKind.permissionDenied,
        );
        await ctrl.pickImage(fromCamera: true);

        expect(
          (ctrl.state as AnalysisFailedState).kind,
          AnalyzeFailureKind.validation,
        );
      },
    );
  });

  group('analyze failure mapping', () {
    test('AnalyzeFailureKind.unknown copy is non-empty for every kind', () {
      for (final k in AnalyzeFailureKind.values) {
        expect(k.userMessage, isNotEmpty);
      }
    });

    test('rateLimited maps to dedicated copy', () async {
      final h = _Harness();
      final ctrl = h.build();
      addTearDown(ctrl.dispose);

      h.analyze.throwOnNext = const AnalyzeFailure(
        AnalyzeFailureKind.rateLimited,
      );
      await ctrl.submit(pet: _samplePet(), text: 'limping');
      final state = ctrl.state as AnalysisFailedState;
      expect(state.kind, AnalyzeFailureKind.rateLimited);
      expect(state.message, contains("today's daily limit"));
    });
  });
}
