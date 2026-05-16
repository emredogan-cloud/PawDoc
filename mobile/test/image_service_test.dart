/// Sprint B2 unit tests for the image-hygiene helpers in
/// [ImageServiceImpl]: magic-byte sniff + dimension header parse.
///
/// We don't drive the full `pickFromGallery` / `captureFromCamera`
/// path here — that requires real platform channels. Instead we
/// exercise the pure-Dart sniffers directly. End-to-end behaviour
/// (including the friendly rejection copy in the controller) is
/// covered by the controller chaos tests.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/shared/services/image_service.dart';

Uint8List _bytes(List<int> v) => Uint8List.fromList(v);

void main() {
  group('detectImageFormat', () {
    test('rejects buffers shorter than the smallest signature', () {
      expect(detectImageFormat(_bytes(const [])), ImageFormat.unknown);
      expect(detectImageFormat(_bytes(const [0xFF, 0xD8])), ImageFormat.unknown);
    });

    test('JPEG via FF D8 FF prefix', () {
      final b = _bytes(const [
        0xFF, 0xD8, 0xFF, 0xE0,
        0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, // JFIF…
      ]);
      expect(detectImageFormat(b), ImageFormat.jpeg);
    });

    test('PNG via 89 50 4E 47 0D 0A 1A 0A signature', () {
      final b = _bytes(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0, 0, 0, 13, // IHDR length placeholder
      ]);
      expect(detectImageFormat(b), ImageFormat.png);
    });

    test('WEBP via RIFF…WEBP', () {
      final b = _bytes(const [
        0x52, 0x49, 0x46, 0x46,
        0, 0, 0, 0,
        0x57, 0x45, 0x42, 0x50,
        0x56, 0x50, 0x38, 0x20, // VP8\x20
      ]);
      expect(detectImageFormat(b), ImageFormat.webp);
    });

    test('HEIC via ftyp box at offset 4', () {
      final b = _bytes(const [
        0, 0, 0, 0x20,
        0x66, 0x74, 0x79, 0x70, // ftyp
        0x68, 0x65, 0x69, 0x63, // heic brand
      ]);
      expect(detectImageFormat(b), ImageFormat.heic);
    });

    test('rejects raw text payloads', () {
      final b = _bytes('<!DOCTYPE html><html><body>'.codeUnits);
      expect(detectImageFormat(b), ImageFormat.unknown);
    });

    test('rejects renamed .html (MIME spoof) — leading "<!"', () {
      final b = _bytes(const [0x3C, 0x21, 0x44, 0x4F, 0x43, 0x54, 0x59, 0x50, 0x45, 0x20, 0x68, 0x74, 0x6D, 0x6C]);
      expect(detectImageFormat(b), ImageFormat.unknown);
    });

    test('rejects gzip prefix (compressed payload)', () {
      final b = _bytes(const [0x1F, 0x8B, 0x08, 0x00, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(detectImageFormat(b), ImageFormat.unknown);
    });
  });

  group('decodeImageDimensions — PNG', () {
    test('reads width/height from IHDR', () {
      final b = _bytes(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG sig
        0, 0, 0, 13, // IHDR length
        0x49, 0x48, 0x44, 0x52, // "IHDR"
        0, 0, 0x04, 0x00, // width  = 1024
        0, 0, 0x03, 0x00, // height = 768
      ]);
      expect(decodeImageDimensions(b), const ImageDimensions(1024, 768));
    });

    test('returns null on truncated PNG', () {
      final b = _bytes(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(decodeImageDimensions(b), isNull);
    });
  });

  group('decodeImageDimensions — JPEG', () {
    test('reads width/height from SOF0', () {
      // FF D8 (SOI), FF E0 segment len 16 (skip), then SOF0
      final b = _bytes(<int>[
        0xFF, 0xD8,
        // APP0 segment, length 16
        0xFF, 0xE0, 0x00, 0x10,
        ...List<int>.filled(14, 0),
        // SOF0
        0xFF, 0xC0, 0x00, 0x11, // length 17
        0x08,                     // precision
        0x03, 0x00,               // height = 768
        0x04, 0x00,               // width  = 1024
        ...List<int>.filled(11, 0),
      ]);
      expect(decodeImageDimensions(b), const ImageDimensions(1024, 768));
    });

    test('returns null when no SOFn marker is present', () {
      final b = _bytes(const [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x04, 0, 0]);
      expect(decodeImageDimensions(b), isNull);
    });
  });

  group('decodeImageDimensions — WEBP (VP8)', () {
    test('reads dimensions from VP8 lossy frame', () {
      // RIFF header (4) + size (4) + WEBP (4) + VP8\x20 (4) + size (4)
      // + 6 padding + 2 bytes for width at offset 26 + 2 bytes for height at 28
      final b = _bytes(<int>[
        0x52, 0x49, 0x46, 0x46, // RIFF
        0, 0, 0, 0,             // size
        0x57, 0x45, 0x42, 0x50, // WEBP
        0x56, 0x50, 0x38, 0x20, // VP8\x20
        0, 0, 0, 0,             // chunk size
        0, 0, 0, 0, 0, 0,       // padding to offset 26
        0x00, 0x04,             // width  = 1024 (LE)
        0x00, 0x03,             // height = 768  (LE)
      ]);
      expect(decodeImageDimensions(b), const ImageDimensions(1024, 768));
    });
  });

  group('ImagePickFailureKind enum', () {
    test('every kind has a stable name', () {
      // Belt-and-braces — analytics serialisation relies on
      // these names not silently renaming.
      expect(ImagePickFailureKind.values.map((e) => e.name).toSet(), {
        'permissionDenied',
        'empty',
        'unsupportedFormat',
        'tooSmall',
        'tooLarge',
        'oversized',
        'compressionFailed',
        'unknown',
      });
    });
  });
}
