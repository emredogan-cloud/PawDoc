// Next Evolution Phase 2 — signed-media-URL TTL cache.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/memories/media_url_cache.dart';

void main() {
  const keyA = 'memories/u1/aaaa.jpg';
  const keyB = 'memories/u1/bbbb.jpg';

  test('caches within TTL: second resolve makes no signer call', () async {
    var calls = 0;
    final service = MediaUrlService(
      signer: (keys) async {
        calls++;
        return ({for (final k in keys) k: 'https://signed/$k'}, 3600);
      },
    );
    final first = await service.resolve([keyA, keyB]);
    expect(first[keyA], 'https://signed/$keyA');
    expect(calls, 1);

    final second = await service.resolve([keyA, keyB]);
    expect(second[keyB], 'https://signed/$keyB');
    expect(calls, 1, reason: 'served from cache inside the TTL');
  });

  test('re-signs after the refresh margin ahead of expiry', () async {
    var calls = 0;
    var now = DateTime(2026, 7, 24, 12);
    final service = MediaUrlService(
      signer: (keys) async {
        calls++;
        return ({for (final k in keys) k: 'https://signed/$calls/$k'}, 3600);
      },
      clock: () => now,
    );
    await service.resolve([keyA]);
    expect(calls, 1);

    // 56 minutes later: inside the 5-minute refresh margin of a 60-minute URL.
    now = now.add(const Duration(minutes: 56));
    final refreshed = await service.resolve([keyA]);
    expect(calls, 2, reason: 'stale-soon URL must be re-signed');
    expect(refreshed[keyA], 'https://signed/2/$keyA');
  });

  test('chunks large batches at the server limit', () async {
    final batchSizes = <int>[];
    final service = MediaUrlService(
      signer: (keys) async {
        batchSizes.add(keys.length);
        return ({for (final k in keys) k: 'u'}, 3600);
      },
    );
    final keys =
        List.generate(30, (i) => 'memories/u1/${i.toString().padLeft(4, '0')}.jpg');
    await service.resolve(keys);
    expect(batchSizes, [MediaUrlService.batchLimit, 30 - MediaUrlService.batchLimit]);
  });

  test('keys the server refuses to sign are absent (fallback path)', () async {
    final service = MediaUrlService(
      // Server drops foreign/malformed keys silently.
      signer: (keys) async => (const <String, String>{}, 3600),
    );
    expect(await service.resolveOne('memories/u2/foreign.jpg'), isNull);
  });
}
