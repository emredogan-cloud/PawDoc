// M1 motion-asset gates (PAWDOC_MOTION_ROADMAP.md §4/§5): every shipped Lottie
// parses, fits the ≤250KB budget, and ships its reduce-motion PNG fallback.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:pawdoc/src/theme/app_assets.dart';

void main() {
  for (final entry in AppMotionAssets.allWithFallbacks.entries) {
    test('${entry.key.split('/').last}: parses, ≤250KB, fallback PNG ships', () async {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: 'missing motion asset ${entry.key}');
      expect(file.lengthSync(), lessThanOrEqualTo(250 * 1024),
          reason: 'budget violation (roadmap §4: Lottie ≤250KB)');

      final composition = await LottieComposition.fromBytes(file.readAsBytesSync());
      expect(composition.durationFrames, greaterThan(0));
      expect(composition.duration.inMilliseconds, greaterThan(500));

      expect(File(entry.value).existsSync(), isTrue,
          reason: 'reduce-motion fallback PNG must ship: ${entry.value}');
    });
  }

  test('referral gift carries the settle + loop markers (A6)', () async {
    final composition = await LottieComposition.fromBytes(
        File(AppMotionAssets.referralGiftIdle).readAsBytesSync());
    expect(composition.getMarker('settle'), isNotNull);
    expect(composition.getMarker('loop'), isNotNull);
    final loop = composition.getMarker('loop')!;
    expect(loop.startFrame, greaterThan(composition.startFrame),
        reason: 'the settle intro must occupy time before the loop point');
  });

  test('sign-in heartbeat is a true one-shot length (~1.2s, never a long loop)',
      () async {
    final composition = await LottieComposition.fromBytes(
        File(AppMotionAssets.signinHeartbeat).readAsBytesSync());
    expect(composition.duration.inMilliseconds, inInclusiveRange(1000, 1500));
  });
}
