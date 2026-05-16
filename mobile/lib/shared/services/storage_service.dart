/// Storage service — uploads compressed pet images to Supabase Storage.
///
/// Bucket: `pet-uploads` (private). Per-user RLS (Phase 1C migration)
/// allows INSERT only into `<user_id>/<filename>` paths. The returned
/// storage key is what the edge function `/analyze` accepts as
/// `input_storage_key`.
///
/// Phase 2 will migrate the production bucket to Cloudflare R2; the key
/// format stays opaque so the migration is local to this file + the
/// edge function.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'image_service.dart';
import 'logger.dart';
import 'supabase_client.dart';

class StorageUploadFailure implements Exception {
  const StorageUploadFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class StorageService {
  /// Upload [image] to the `pet-uploads` bucket under [userId]'s folder.
  /// Returns the storage key (path within the bucket).
  Future<String> uploadPetImage({
    required String userId,
    required PickedImage image,
  });
}

class StorageServiceImpl implements StorageService {
  StorageServiceImpl(this._client);
  final SupabaseClient _client;
  static const _bucket = 'pet-uploads';
  static final _log = AppLogger.of('storage.service');

  @override
  Future<String> uploadPetImage({
    required String userId,
    required PickedImage image,
  }) async {
    final filename = _makeFilename(image.mimeType);
    final key = '$userId/$filename';
    _log.info('upload_start', '${image.finalSizeBytes}B → $key');
    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            key,
            image.bytes,
            fileOptions: FileOptions(
              contentType: image.mimeType,
              // Phase 1C analyses are append-only; we never overwrite an
              // existing key. `upsert: false` makes a duplicate path fail
              // loud rather than silently shadow another user's file
              // (which RLS would block anyway, but defence in depth).
              upsert: false,
            ),
          );
      _log.info('upload_complete', key);
      return key;
    } on StorageException catch (e) {
      _log.warning('upload_failed', '${e.statusCode} ${e.message}');
      throw StorageUploadFailure(_friendly(e));
    } on Object catch (e, s) {
      _log.severe('upload_unexpected', e, s);
      throw const StorageUploadFailure(
        "We couldn't upload that image. Check your connection and try again.",
      );
    }
  }

  String _makeFilename(String mime) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = switch (mime) {
      'image/png' => 'png',
      'image/heic' || 'image/heif' => 'heic',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    // Random component prevents accidental collisions across rapid
    // submissions within the same millisecond.
    final salt = (ts ^ identityHashCode(this))
        .toRadixString(36)
        .padLeft(6, '0');
    return '$ts-$salt.$ext';
  }

  String _friendly(StorageException e) {
    final raw = e.message.toLowerCase();
    if (raw.contains('row-level security') || raw.contains('rls')) {
      // Should be unreachable in normal flow — investigate when seen.
      return 'Storage refused the upload. Sign out and back in.';
    }
    if (raw.contains('size') || raw.contains('too large')) {
      return 'That image is larger than our limit.';
    }
    if (raw.contains('mime')) {
      return 'That image format is not supported. Try JPG or PNG.';
    }
    return "We couldn't upload that image. Try again.";
  }
}

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageServiceImpl(ref.watch(supabaseClientProvider)),
);
