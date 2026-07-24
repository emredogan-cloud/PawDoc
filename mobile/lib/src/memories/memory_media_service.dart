import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/image_compressor.dart';
import '../capture/upload_service.dart';

/// Isolate entrypoint: same EXIF/GPS-stripping compressor as the analysis
/// capture flow (CR #7) — a journal photo gets the identical privacy treatment.
CompressionResult compressMemoryBytes(Uint8List raw) => compressForUpload(raw);

/// Picks (camera or gallery via the system photo picker), compresses in a
/// background isolate, and uploads to the caller's own `memories/<uid>/…`
/// namespace via the presigned-PUT flow. No R2 credentials on the client.
class MemoryMediaService {
  MemoryMediaService(this._uploads, {ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final UploadService _uploads;
  final ImagePicker _picker;

  /// Returns raw bytes, or null when the user cancels the picker.
  Future<Uint8List?> pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      // Bound the decode cost before our own compressor runs.
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  /// Compress (isolate) + upload. Returns the R2 storage key.
  Future<String> compressAndUpload(Uint8List raw) async {
    final compressed = await compute(compressMemoryBytes, raw);
    final result =
        await _uploads.uploadJpeg(compressed.bytes, scope: 'memories');
    return result.storageKey;
  }
}

final memoryMediaServiceProvider = Provider<MemoryMediaService>((ref) {
  return MemoryMediaService(ref.watch(uploadServiceProvider));
});
