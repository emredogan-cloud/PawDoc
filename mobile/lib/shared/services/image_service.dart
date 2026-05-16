/// Image capture + compression pipeline.
///
/// Source of truth for picking a photo, downscaling, and re-encoding to
/// JPEG below the 2 MB budget. The result is a [PickedImage] containing
/// raw bytes ready for upload — no temp-file lifecycle for the caller to
/// manage.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'logger.dart';

const int _kMaxBytes = 2 * 1024 * 1024;

@immutable
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.mimeType,
    required this.originalSizeBytes,
    required this.finalSizeBytes,
  });

  final Uint8List bytes;
  final String mimeType;
  final int originalSizeBytes;
  final int finalSizeBytes;

  bool get wasCompressed => finalSizeBytes < originalSizeBytes;
}

class ImagePickFailure implements Exception {
  const ImagePickFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin interface so tests can stub the pipeline without touching the
/// platform-specific ImagePicker singleton.
abstract class ImageService {
  Future<PickedImage?> captureFromCamera();
  Future<PickedImage?> pickFromGallery();
}

class ImageServiceImpl implements ImageService {
  ImageServiceImpl({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  static final _log = AppLogger.of('image.service');

  @override
  Future<PickedImage?> captureFromCamera() =>
      _pickAndCompress(ImageSource.camera);

  @override
  Future<PickedImage?> pickFromGallery() =>
      _pickAndCompress(ImageSource.gallery);

  Future<PickedImage?> _pickAndCompress(ImageSource source) async {
    final XFile? raw;
    try {
      raw = await _picker.pickImage(
        source: source,
        // The plugin downscales here as a first pass; we re-encode if the
        // result is still too large.
        maxWidth: 2048,
        imageQuality: 85,
      );
    } on Object catch (e, s) {
      _log.warning('image_pick_failed', e);
      if (e.toString().toLowerCase().contains('permission')) {
        throw const ImagePickFailure(
          'Permission denied. Allow camera/photos access in Settings.',
        );
      }
      _log.severe('image_pick_unexpected', e, s);
      throw const ImagePickFailure('Could not load that image.');
    }
    if (raw == null) return null; // user cancelled

    final originalBytes = await raw.readAsBytes();
    var current = originalBytes;
    var quality = 85;
    var maxWidth = 2048;
    // Iteratively shrink if necessary.
    while (current.length > _kMaxBytes && quality > 40) {
      final recompressed = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: maxWidth,
        minHeight: maxWidth,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      current = recompressed;
      // Either reduce quality or downscale on the next round.
      if (quality > 60) {
        quality -= 15;
      } else {
        maxWidth = (maxWidth * 0.75).round();
      }
    }

    if (current.length > _kMaxBytes) {
      _log.warning(
        'image_too_large_after_compression',
        '${current.length}B exceeds ${_kMaxBytes}B',
      );
      throw const ImagePickFailure(
        'That image is too large to send. Try a different one.',
      );
    }

    _log.info('image_ready_${originalBytes.length}_${current.length}');

    return PickedImage(
      bytes: current,
      mimeType: 'image/jpeg',
      originalSizeBytes: originalBytes.length,
      finalSizeBytes: current.length,
    );
  }
}

final imageServiceProvider = Provider<ImageService>((_) => ImageServiceImpl());
