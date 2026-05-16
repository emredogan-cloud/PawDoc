/// Image capture + compression pipeline.
///
/// Source of truth for picking a photo, downscaling, and re-encoding to
/// JPEG below the 2 MB budget. The result is a [PickedImage] containing
/// raw bytes ready for upload — no temp-file lifecycle for the caller to
/// manage.
///
/// Sprint B2 hygiene (abuse + App Store safety):
///   - Magic-byte sniff on the final bytes so a renamed `.html` /
///     polyglot file never reaches the storage bucket. Belt-and-braces
///     with `flutter_image_compress` (which produces JPEG already).
///   - Dimension sanity: reject 1×1 / banner-shaped images that can't
///     yield a useful triage signal and are often automation markers.
///   - All rejections raise [ImagePickFailure] with a stable
///     [ImagePickFailureKind] so the analyze controller can map to
///     `AnalyzeFailureKind.unsupportedImage` for analytics + UX.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'logger.dart';

const int _kMaxBytes = 2 * 1024 * 1024;
const int _kMinDimensionPx = 200;
const int _kMaxDimensionPx = 8000;

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

/// Stable kinds for failure mapping. The mobile capture screen renders
/// `message`; the analyze controller branches on `kind` to drive
/// analytics + the `AnalyzeFailureKind.unsupportedImage` flow.
enum ImagePickFailureKind {
  permissionDenied,
  empty,
  unsupportedFormat,
  tooSmall,
  tooLarge,
  oversized,
  compressionFailed, // Sprint B3 (F-OPS6): OOM / native crash inside flutter_image_compress
  unknown;
}

class ImagePickFailure implements Exception {
  const ImagePickFailure(this.message, {this.kind = ImagePickFailureKind.unknown});
  final String message;
  final ImagePickFailureKind kind;
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
          kind: ImagePickFailureKind.permissionDenied,
        );
      }
      _log.severe('image_pick_unexpected', e, s);
      throw const ImagePickFailure(
        'Could not load that image.',
        kind: ImagePickFailureKind.unknown,
      );
    }
    if (raw == null) return null; // user cancelled

    final originalBytes = await raw.readAsBytes();
    if (originalBytes.isEmpty) {
      _log.warning('image_empty_after_pick');
      throw const ImagePickFailure(
        'That image was empty. Try a different one.',
        kind: ImagePickFailureKind.empty,
      );
    }

    var current = originalBytes;
    var quality = 85;
    var maxWidth = 2048;
    // Iteratively shrink if necessary.
    while (current.length > _kMaxBytes && quality > 40) {
      // Sprint B3 (F-OPS6 / R-16): flutter_image_compress runs on the
      // platform thread on iOS but in-process on Android; on a 256 MB
      // Android device it can OOM or return empty bytes. We wrap each
      // call in try/catch and additionally guard against empty output.
      // The full `compute()`-isolate rewrite stays deferred to Phase 2
      // (P1.15); this wrapper is the safety net for the existing
      // main-isolate path so a low-end device sees a friendly typed
      // failure rather than a generic crash bubbling out as `.unknown`.
      Uint8List recompressed;
      try {
        recompressed = await FlutterImageCompress.compressWithList(
          originalBytes,
          minWidth: maxWidth,
          minHeight: maxWidth,
          quality: quality,
          format: CompressFormat.jpeg,
        );
      } on Object catch (e, s) {
        _log.warning(
          'image_compress_failed',
          '$e (quality=$quality maxWidth=$maxWidth)',
        );
        _log.severe('image_compress_failed_stack', e, s);
        throw const ImagePickFailure(
          "We couldn't shrink that image. Try a different one.",
          kind: ImagePickFailureKind.compressionFailed,
        );
      }
      if (recompressed.isEmpty) {
        _log.warning(
          'image_compress_returned_empty',
          'quality=$quality maxWidth=$maxWidth',
        );
        throw const ImagePickFailure(
          "We couldn't shrink that image. Try a different one.",
          kind: ImagePickFailureKind.compressionFailed,
        );
      }
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
        kind: ImagePickFailureKind.oversized,
      );
    }

    // Magic-byte sniff. Picker + flutter_image_compress should give us
    // JPEG bytes, but a future regression / device quirk could leave us
    // with raw originalBytes containing something else. Sniff the
    // final buffer that's about to be uploaded.
    final sniffed = detectImageFormat(current);
    if (sniffed == ImageFormat.unknown) {
      _log.warning('image_unsupported_format', _firstBytesHex(current));
      throw const ImagePickFailure(
        'That file type isn\'t supported. Use a JPG, PNG, HEIC, or WEBP.',
        kind: ImagePickFailureKind.unsupportedFormat,
      );
    }

    // Dimension sanity check via header parse. We deliberately do NOT
    // decode the pixel array (the OS-level decoder allocates the full
    // bitmap on the UI thread). Header parse runs in microseconds.
    final dims = decodeImageDimensions(current, sniffed);
    if (dims != null) {
      if (dims.width < _kMinDimensionPx || dims.height < _kMinDimensionPx) {
        _log.warning(
          'image_too_small',
          '${dims.width}x${dims.height} < $_kMinDimensionPx',
        );
        throw const ImagePickFailure(
          'That image is too small. Try a clearer photo (at least '
          '$_kMinDimensionPx×$_kMinDimensionPx pixels).',
          kind: ImagePickFailureKind.tooSmall,
        );
      }
      if (dims.width > _kMaxDimensionPx || dims.height > _kMaxDimensionPx) {
        _log.warning(
          'image_too_tall_or_wide',
          '${dims.width}x${dims.height} > $_kMaxDimensionPx',
        );
        throw const ImagePickFailure(
          'That image is unusually large. Try a normal photo.',
          kind: ImagePickFailureKind.tooLarge,
        );
      }
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

// -----------------------------------------------------------------------------
// Magic-byte / dimension utilities (visible for testing)
// -----------------------------------------------------------------------------

/// Subset of image formats we accept. Unknown means "reject — don't
/// upload this."
enum ImageFormat { jpeg, png, webp, heic, unknown }

@immutable
class ImageDimensions {
  const ImageDimensions(this.width, this.height);
  final int width;
  final int height;
  @override
  bool operator ==(Object other) =>
      other is ImageDimensions && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(width, height);
  @override
  String toString() => '${width}x$height';
}

/// Sniff the first ~16 bytes of [bytes] against the format table. Public
/// only for tests; the production call site is `_pickAndCompress`.
@visibleForTesting
ImageFormat detectImageFormat(Uint8List bytes) {
  if (bytes.length < 12) return ImageFormat.unknown;

  // JPEG — FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return ImageFormat.jpeg;
  }
  // PNG — 89 50 4E 47 0D 0A 1A 0A
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return ImageFormat.png;
  }
  // WEBP — RIFF....WEBP
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return ImageFormat.webp;
  }
  // HEIC — `ftyp` at offset 4, brand at offset 8.
  if (bytes.length >= 12 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    // We accept any HEIC/HEIF brand prefix.
    return ImageFormat.heic;
  }
  return ImageFormat.unknown;
}

/// Parse the image's pixel dimensions from header bytes. Returns null
/// when the format isn't supported here or the header is truncated.
/// Public only for tests.
@visibleForTesting
ImageDimensions? decodeImageDimensions(Uint8List bytes, [ImageFormat? format]) {
  final fmt = format ?? detectImageFormat(bytes);
  switch (fmt) {
    case ImageFormat.png:
      return _decodePng(bytes);
    case ImageFormat.jpeg:
      return _decodeJpeg(bytes);
    case ImageFormat.webp:
      return _decodeWebp(bytes);
    case ImageFormat.heic:
    case ImageFormat.unknown:
      // HEIC dimensions live in nested boxes — out of scope for B2's
      // tiny sniffer. Returning null skips the dimension gate; the
      // size + magic-byte gates still apply.
      return null;
  }
}

ImageDimensions? _decodePng(Uint8List b) {
  // Width = big-endian uint32 at offset 16, height at 20. IHDR is the
  // first chunk; total minimum file size is 24 bytes for the header.
  if (b.length < 24) return null;
  final width = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
  final height = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
  if (width <= 0 || height <= 0) return null;
  return ImageDimensions(width, height);
}

ImageDimensions? _decodeJpeg(Uint8List b) {
  // Walk the markers looking for SOF0/SOF1/SOF2 (FF C0/C1/C2). Skip
  // standalone markers (FF 00 / restart) and length-prefixed segments.
  var i = 2; // skip SOI (FF D8)
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) return null;
    final marker = b[i + 1];
    // Skip RSTn, padding.
    if (marker == 0xFF || (marker >= 0xD0 && marker <= 0xD9) || marker == 0x00) {
      i += 1;
      continue;
    }
    if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
      // SOFn payload: [length(2)] [precision(1)] [height(2)] [width(2)]
      if (i + 9 >= b.length) return null;
      final height = (b[i + 5] << 8) | b[i + 6];
      final width = (b[i + 7] << 8) | b[i + 8];
      if (width <= 0 || height <= 0) return null;
      return ImageDimensions(width, height);
    }
    // length includes the two length bytes themselves.
    final segLen = (b[i + 2] << 8) | b[i + 3];
    if (segLen < 2) return null;
    i += 2 + segLen;
  }
  return null;
}

ImageDimensions? _decodeWebp(Uint8List b) {
  // Need at least the RIFF/WEBP header + chunk header (30 bytes).
  if (b.length < 30) return null;
  // VP8 / VP8L / VP8X variants. The chunk type is at offset 12.
  final c = String.fromCharCodes(b.sublist(12, 16));
  switch (c) {
    case 'VP8 ':
      // Width/height at offsets 26+ (10-bit fields, little-endian).
      if (b.length < 30) return null;
      final w = ((b[26] | (b[27] << 8)) & 0x3FFF);
      final h = ((b[28] | (b[29] << 8)) & 0x3FFF);
      return ImageDimensions(w, h);
    case 'VP8L':
      if (b.length < 25) return null;
      // 14 bits width-1 + 14 bits height-1 starting at byte 21.
      final w = ((b[21] | (b[22] << 8)) & 0x3FFF) + 1;
      final h = (((b[22] >> 6) | (b[23] << 2) | (b[24] << 10)) & 0x3FFF) + 1;
      return ImageDimensions(w, h);
    case 'VP8X':
      // Width-1, height-1 as 24-bit little-endian at offsets 24, 27.
      if (b.length < 30) return null;
      final w = (b[24] | (b[25] << 8) | (b[26] << 16)) + 1;
      final h = (b[27] | (b[28] << 8) | (b[29] << 16)) + 1;
      return ImageDimensions(w, h);
    default:
      return null;
  }
}

String _firstBytesHex(Uint8List b) {
  final n = b.length < 6 ? b.length : 6;
  final sb = StringBuffer();
  for (var i = 0; i < n; i++) {
    sb.write(b[i].toRadixString(16).padLeft(2, '0'));
    if (i + 1 < n) sb.write(' ');
  }
  return sb.toString();
}

final imageServiceProvider = Provider<ImageService>((_) => ImageServiceImpl());
