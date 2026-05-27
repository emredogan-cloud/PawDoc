import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pawdoc/src/capture/image_compressor.dart';
import 'package:pawdoc/src/capture/image_quality.dart';

void main() {
  group('compressForUpload', () {
    test('strips EXIF/GPS metadata from the output (CR #7)', () {
      final src = img.Image(width: 200, height: 150);
      img.fill(src, color: img.ColorRgb8(100, 140, 90));
      src.exif.imageIfd['Make'] = 'PawCam';
      src.exif.gpsIfd['GPSLatitudeRef'] = 'N';
      final withMeta = Uint8List.fromList(img.encodeJpg(src));

      final out = img.decodeJpg(compressForUpload(withMeta).bytes)!;
      expect(out.exif.imageIfd.isEmpty, isTrue, reason: 'image EXIF must be stripped');
      expect(out.exif.gpsIfd.isEmpty, isTrue, reason: 'GPS EXIF must be stripped');
    });

    test('keeps output under 2MB and within max dimension', () {
      final src = img.Image(width: 2200, height: 1500);
      final rnd = Random(7);
      for (int y = 0; y < src.height; y++) {
        for (int x = 0; x < src.width; x++) {
          src.setPixelRgb(x, y, rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256));
        }
      }
      final big = Uint8List.fromList(img.encodeJpg(src, quality: 100));

      final result = compressForUpload(big);
      expect(result.sizeBytes, lessThanOrEqualTo(kMaxUploadBytes));
      expect(result.width, lessThanOrEqualTo(1600));
    });

    test('rejects corrupt input', () {
      expect(
        () => compressForUpload(Uint8List.fromList([0, 1, 2, 3])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('assessQuality', () {
    test('flags a flat dark frame as too dark and blurry', () {
      final dark = img.Image(width: 200, height: 200);
      img.fill(dark, color: img.ColorRgb8(8, 8, 8));
      final r = assessQuality(dark);
      expect(r.brightness, lessThan(0.22));
      expect(r.hints.any((h) => h.contains('dark')), isTrue);
      expect(r.hints.any((h) => h.contains('blurry')), isTrue);
    });

    test('a detailed mid-brightness frame is acceptable', () {
      final cb = img.Image(width: 200, height: 200);
      for (int y = 0; y < 200; y++) {
        for (int x = 0; x < 200; x++) {
          final on = ((x ~/ 8) + (y ~/ 8)) % 2 == 0;
          final v = on ? 200 : 60;
          cb.setPixelRgb(x, y, v, v, v);
        }
      }
      final r = assessQuality(cb);
      expect(r.brightness, inInclusiveRange(0.22, 0.88));
      expect(r.sharpness, greaterThan(6.0));
      expect(r.isAcceptable, isTrue);
    });
  });
}
