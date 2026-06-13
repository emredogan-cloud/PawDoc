import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/capture/image_compressor.dart' show kMaxUploadBytes;
import 'package:pawdoc/src/capture/upload_service.dart';

void main() {
  group('validateUploadBytes (E8c size/empty guard)', () {
    test('rejects empty bytes with a calm message', () {
      expect(
        () => validateUploadBytes(Uint8List(0)),
        throwsA(isA<UploadException>()),
      );
    });

    test('rejects oversized bytes (large uploads fail gracefully)', () {
      final tooBig = Uint8List(kMaxUploadBytes + 1);
      expect(
        () => validateUploadBytes(tooBig),
        throwsA(isA<UploadException>()),
      );
    });

    test('accepts a normal payload', () {
      expect(() => validateUploadBytes(Uint8List(1024)), returnsNormally);
    });
  });

  test('upload bounds are finite (uploads never spin forever)', () {
    expect(kUploadUrlTimeout.inSeconds, greaterThan(0));
    expect(kUploadPutTimeout.inSeconds, greaterThan(0));
    expect(kUploadMaxAttempts, inInclusiveRange(1, 5));
  });
}
