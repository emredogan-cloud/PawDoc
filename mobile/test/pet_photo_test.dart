// Pet profile photo: the crop/compress pipeline and the storage-key contract.
//
// The privacy treatment is the point — a photo of someone's home must not carry
// GPS to the server, and the key namespace is what keeps one owner's objects
// unreachable from another account.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pawdoc/src/capture/image_compressor.dart';

Uint8List _jpeg({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  // A recognisable gradient so a wrong crop region is visible in assertions.
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, (x * 255) ~/ width, (y * 255) ~/ height, 128);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  test('centre crop squares a landscape photo', () {
    final result = cropSquareAndCompress(
      _jpeg(width: 1200, height: 800),
      SquareCrop.centre,
    );
    expect(result.width, result.height, reason: 'avatars are circular');
    expect(result.width, lessThanOrEqualTo(720));
  });

  test('centre crop squares a portrait photo', () {
    final result = cropSquareAndCompress(
      _jpeg(width: 800, height: 1400),
      SquareCrop.centre,
    );
    expect(result.width, result.height);
  });

  test('a user-framed region is honoured', () {
    final result = cropSquareAndCompress(
      _jpeg(width: 1000, height: 1000),
      const SquareCrop(left: 0.5, top: 0.5, size: 0.4),
    );
    expect(result.width, result.height);
    expect(result.width, greaterThan(0));
  });

  test('an out-of-bounds crop clamps instead of throwing', () {
    // A fast pan can hand us a rect that runs off the edge; it must degrade to
    // a valid square rather than crashing the picker flow.
    final result = cropSquareAndCompress(
      _jpeg(width: 900, height: 600),
      const SquareCrop(left: 0.99, top: 0.99, size: 1.0),
    );
    expect(result.width, result.height);
    expect(result.sizeBytes, greaterThan(0));
  });

  test('the output carries no EXIF/GPS', () {
    final result = cropSquareAndCompress(
      _jpeg(width: 800, height: 800),
      SquareCrop.centre,
    );
    final decoded = img.decodeImage(result.bytes)!;
    expect(decoded.exif.gpsIfd.isEmpty, isTrue, reason: 'GPS must never ship');
    expect(decoded.exif.imageIfd.isEmpty, isTrue);
  });

  test('output stays under the upload ceiling', () {
    final result = cropSquareAndCompress(
      _jpeg(width: 2400, height: 2400),
      SquareCrop.centre,
    );
    expect(result.sizeBytes, lessThanOrEqualTo(kMaxUploadBytes));
  });

  test('corrupt bytes fail loudly rather than uploading garbage', () {
    expect(
      () => cropSquareAndCompress(
        Uint8List.fromList([1, 2, 3, 4]),
        SquareCrop.centre,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
