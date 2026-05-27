import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

/// Max recorded clip length (roadmap §3.2).
const int kMaxVideoSeconds = 30;

/// How many keyframes to sample (roadmap says 4–6).
const int kKeyframeCount = 5;

/// Evenly-spaced sample timestamps (ms) across a clip of [durationMs], avoiding
/// the very first/last frames by placing sample i at (i)/(count+1) of duration.
/// Pure + unit-tested; the actual frame extraction below uses these.
List<int> keyframeTimestamps(int durationMs, int count) {
  if (durationMs <= 0 || count <= 0) return const [];
  final timestamps = <int>[];
  for (var i = 1; i <= count; i++) {
    timestamps.add((durationMs * i / (count + 1)).round());
  }
  return timestamps;
}

/// Extract up to [count] JPEG keyframes from a local [videoPath], evenly spaced
/// across [durationMs]. Each frame is produced by the native platform extractor
/// (Android MediaMetadataRetriever / iOS AVAssetImageGenerator) via the
/// `video_thumbnail` plugin — no ffmpeg. Returns frames in chronological order;
/// frames that fail to decode are skipped. The plugin calls run on a platform
/// channel (off the Dart UI work), so this does not block the UI thread.
Future<List<Uint8List>> extractKeyframes(
  String videoPath,
  int durationMs, {
  int count = kKeyframeCount,
  int maxWidth = 1024,
}) async {
  final frames = <Uint8List>[];
  for (final timeMs in keyframeTimestamps(durationMs, count)) {
    final data = await VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      timeMs: timeMs,
      maxWidth: maxWidth,
      quality: 70,
    );
    if (data != null && data.isNotEmpty) frames.add(data);
  }
  return frames;
}
