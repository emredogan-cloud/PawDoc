import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import '../capture/image_compressor.dart';
import '../capture/upload_service.dart';
import '../memories/media_url_cache.dart';

/// Isolate payload — `compute` takes a single argument.
class _CropJob {
  const _CropJob(this.bytes, this.crop);
  final Uint8List bytes;
  final SquareCrop crop;
}

/// Isolate entrypoint: square-crop, bake orientation, strip EXIF/GPS, compress.
CompressionResult _cropAndCompress(_CropJob job) =>
    cropSquareAndCompress(job.bytes, job.crop);

/// The pet's profile photo: pick, crop, compress, upload, replace, remove.
///
/// Deliberately built on the pieces the journal already uses — the same
/// EXIF-stripping compressor, the same presigned-PUT upload (no R2 credentials
/// on the client), the same signed-GET cache for display. Only the storage
/// scope differs (`pets/`), which is what makes the object displayable and
/// owner-deletable.
class PetPhotoService {
  PetPhotoService(
    this._uploads,
    this._media,
    this._client, {
    ImagePicker? picker,
  }) : _picker = picker ?? ImagePicker();

  final UploadService _uploads;
  final MediaUrlService _media;
  final SupabaseClient _client;
  final ImagePicker _picker;

  /// Raw bytes from the camera or the system photo picker; null if cancelled.
  ///
  /// The picker's own bound keeps the decode cheap; the real downscale happens
  /// after cropping so the user's framing is applied at full fidelity.
  Future<Uint8List?> pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  /// Crop + compress off the UI isolate, then upload. Returns the storage key.
  Future<String> cropAndUpload(Uint8List raw, SquareCrop crop) async {
    final processed = await compute(_cropAndCompress, _CropJob(raw, crop));
    final result = await _uploads.uploadJpeg(processed.bytes, scope: 'pets');
    return result.storageKey;
  }

  /// Best-effort removal of a replaced/cleared photo.
  ///
  /// The database row is the source of truth for what is displayed, so a failed
  /// object delete must never block the user's edit — the orphan is swept by
  /// the account-deletion purge. Also drops the signed-URL cache entry so a
  /// replaced photo cannot linger on screen.
  Future<void> discard(String? storageKey) async {
    if (storageKey == null || storageKey.isEmpty) return;
    _media.evict(storageKey);
    try {
      // Own `pets/<uid>/…` keys only — enforced server-side by delete-media.
      await _client.functions.invoke('delete-media', body: {'key': storageKey});
    } catch (_) {
      // Intentionally swallowed — see above.
    }
  }
}

final petPhotoServiceProvider = Provider<PetPhotoService>((ref) {
  return PetPhotoService(
    ref.watch(uploadServiceProvider),
    ref.watch(mediaUrlServiceProvider),
    ref.watch(supabaseClientProvider),
  );
});
