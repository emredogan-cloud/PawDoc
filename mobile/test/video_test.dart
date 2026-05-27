import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/capture/keyframe_extractor.dart';

void main() {
  group('keyframeTimestamps', () {
    test('evenly spaced across the clip, avoiding first/last frame', () {
      // 5 frames over 12s -> at 2,4,6,8,10s (i/(5+1) * 12000).
      expect(keyframeTimestamps(12000, 5), [2000, 4000, 6000, 8000, 10000]);
    });

    test('first sample > 0 and last sample < duration', () {
      final ts = keyframeTimestamps(9999, kKeyframeCount);
      expect(ts.length, kKeyframeCount);
      expect(ts.first, greaterThan(0));
      expect(ts.last, lessThan(9999));
    });

    test('timestamps are strictly increasing', () {
      final ts = keyframeTimestamps(30000, kKeyframeCount);
      for (var i = 1; i < ts.length; i++) {
        expect(ts[i], greaterThan(ts[i - 1]));
      }
    });

    test('degenerate inputs yield no timestamps', () {
      expect(keyframeTimestamps(0, 5), isEmpty);
      expect(keyframeTimestamps(12000, 0), isEmpty);
      expect(keyframeTimestamps(-5, 5), isEmpty);
    });

    test('defaults match the roadmap (4–6 frames, ≤30s)', () {
      expect(kKeyframeCount, inInclusiveRange(4, 6));
      expect(kMaxVideoSeconds, 30);
    });
  });
}
