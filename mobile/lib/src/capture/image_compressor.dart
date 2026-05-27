import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Result of preparing an image for upload.
class CompressionResult {
  const CompressionResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  int get sizeBytes => bytes.length;
}

/// Upload size ceiling (roadmap: images must be < 2MB before upload).
const int kMaxUploadBytes = 2 * 1024 * 1024;

/// Prepare a captured image for upload:
///  1. decode,
///  2. **strip ALL metadata incl. EXIF/GPS (CR #7)** by clearing it before re-encoding,
///  3. downscale to a sane max dimension,
///  4. re-encode JPEG, stepping quality down until under [maxBytes].
///
/// Pure function (no I/O) so it is unit-testable headlessly.
CompressionResult compressForUpload(
  Uint8List input, {
  int maxBytes = kMaxUploadBytes,
  int maxDimension = 1600,
}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (e) {
    // The image package can throw (not just return null) on malformed bytes.
    throw FormatException('Unsupported or corrupt image data: $e');
  }
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image data');
  }

  img.Image working = decoded;
  if (working.width > maxDimension || working.height > maxDimension) {
    working = working.width >= working.height
        ? img.copyResize(working, width: maxDimension)
        : img.copyResize(working, height: maxDimension);
  }

  // CR #7: remove EXIF/GPS. A fresh ExifData() has no tags; encodeJpg then
  // writes no metadata. (Re-encoding alone is not guaranteed to drop it.)
  working.exif = img.ExifData();

  for (final quality in const [85, 75, 65, 55, 45, 35]) {
    final bytes = img.encodeJpg(working, quality: quality);
    if (bytes.length <= maxBytes) {
      return CompressionResult(bytes: bytes, width: working.width, height: working.height);
    }
  }

  // Last resort: downscale further at the lowest quality.
  final smaller = img.copyResize(working, width: (working.width * 0.6).round());
  smaller.exif = img.ExifData();
  return CompressionResult(
    bytes: img.encodeJpg(smaller, quality: 35),
    width: smaller.width,
    height: smaller.height,
  );
}
