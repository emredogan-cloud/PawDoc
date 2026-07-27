import 'dart:math' as math;
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

  // E8b (CR #7): bake the EXIF orientation into the pixels BEFORE stripping
  // metadata. Decoding does NOT auto-apply the orientation flag, so clearing
  // EXIF without baking first would upload a sideways photo. (copyResize bakes
  // too, but only the large-image path resizes — a small oriented photo would
  // skip it — so bake explicitly here for every image.)
  img.Image working = img.bakeOrientation(decoded);
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

/// A square crop of [input], expressed in fractions of the *oriented* image.
///
/// The pet-photo crop UI hands back where the user framed the subject; the
/// pixels are cut here, in the same isolate that compresses, so the phone never
/// decodes the full image twice. Values are clamped, so a crop rect that drifts
/// off the edge yields a smaller valid square rather than an exception.
class SquareCrop {
  const SquareCrop({required this.left, required this.top, required this.size});

  /// Fractions in [0, 1] of the oriented image's width/height.
  final double left;
  final double top;

  /// Side length as a fraction of the image's *shorter* edge.
  final double size;

  /// The whole image, centred — what an untouched crop UI produces.
  static const centre = SquareCrop(left: -1, top: -1, size: 1);
}

/// Crop to a square, then run the normal [compressForUpload] treatment
/// (orientation baked, EXIF/GPS stripped, downscaled, JPEG re-encoded).
///
/// Avatars are rendered in circles at small sizes everywhere, so a square
/// source keeps every surface consistent and avoids per-screen letterboxing.
CompressionResult cropSquareAndCompress(
  Uint8List input,
  SquareCrop crop, {
  int maxDimension = 720,
}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (e) {
    throw FormatException('Unsupported or corrupt image data: $e');
  }
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupt image data');
  }

  // Bake orientation FIRST: the crop rect the user drew refers to what they
  // saw on screen, which is the oriented image, not the raw sensor buffer.
  final oriented = img.bakeOrientation(decoded);
  final shortEdge = math.min(oriented.width, oriented.height);

  final int side;
  final int x;
  final int y;
  if (crop.left < 0 || crop.top < 0) {
    side = shortEdge;
    x = (oriented.width - side) ~/ 2;
    y = (oriented.height - side) ~/ 2;
  } else {
    side = (crop.size.clamp(0.05, 1.0) * shortEdge).round().clamp(1, shortEdge);
    x = (crop.left * oriented.width).round().clamp(0, oriented.width - side);
    y = (crop.top * oriented.height).round().clamp(0, oriented.height - side);
  }

  final square = img.copyCrop(oriented, x: x, y: y, width: side, height: side);
  // Re-encode through the shared path so EXIF stripping and the size ceiling
  // stay defined in exactly one place.
  return compressForUpload(
    img.encodeJpg(square, quality: 95),
    maxDimension: maxDimension,
  );
}
