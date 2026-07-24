import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';

/// A presigned GET URL with its expiry.
class SignedMediaUrl {
  const SignedMediaUrl({required this.url, required this.expiresAt});
  final String url;
  final DateTime expiresAt;
}

/// Batch signer signature — injectable for tests. Given storage keys, returns
/// `{key: url}` for the keys the server agreed to sign (foreign/malformed keys
/// are silently absent) plus the TTL in seconds.
typedef MediaSigner = Future<(Map<String, String>, int)> Function(
    List<String> keys);

/// Resolves storage keys (`memories/<uid>/…`, `chat/<uid>/…`) to short-lived
/// signed GET URLs via the `sign-media-url` Edge Function, with an in-memory
/// TTL cache so scrolling a gallery doesn't re-sign every cell. Image bytes are
/// cached by [CachedNetworkImage] keyed on the STORAGE KEY (stable), so URL
/// rotation never re-downloads pixels.
class MediaUrlService {
  MediaUrlService({required MediaSigner signer, DateTime Function()? clock})
      : _signer = signer,
        _clock = clock ?? DateTime.now;

  final MediaSigner _signer;
  final DateTime Function() _clock;
  final Map<String, SignedMediaUrl> _cache = {};

  /// Refresh signed URLs this long before they actually expire, so an image
  /// widget never receives a URL that dies mid-download.
  static const Duration refreshMargin = Duration(minutes: 5);

  /// Edge Function batch cap (mirrors MAX_KEYS_PER_REQUEST server-side).
  static const int batchLimit = 24;

  /// Resolve [keys] to displayable URLs. Unknown/foreign keys are absent from
  /// the result (the server refuses to sign them) — callers render a fallback.
  Future<Map<String, String>> resolve(List<String> keys) async {
    final now = _clock();
    final result = <String, String>{};
    final needed = <String>[];
    for (final key in keys) {
      final hit = _cache[key];
      if (hit != null && hit.expiresAt.subtract(refreshMargin).isAfter(now)) {
        result[key] = hit.url;
      } else if (!needed.contains(key)) {
        needed.add(key);
      }
    }
    for (var i = 0; i < needed.length; i += batchLimit) {
      final chunk = needed.sublist(
          i, i + batchLimit > needed.length ? needed.length : i + batchLimit);
      final (urls, expiresIn) = await _signer(chunk);
      final expiresAt = _clock().add(Duration(seconds: expiresIn));
      urls.forEach((key, url) {
        _cache[key] = SignedMediaUrl(url: url, expiresAt: expiresAt);
        result[key] = url;
      });
    }
    return result;
  }

  /// Single-key convenience; null when the server refused to sign it.
  Future<String?> resolveOne(String key) async => (await resolve([key]))[key];
}

/// Production signer: calls the `sign-media-url` Edge Function with the
/// caller's JWT (verify_jwt) — the server only ever signs the user's own keys.
MediaSigner supabaseMediaSigner(SupabaseClient client) {
  return (List<String> keys) async {
    final res = await client.functions.invoke(
      'sign-media-url',
      body: {'keys': keys},
    );
    final data = res.data;
    if (data is! Map) return (const <String, String>{}, 0);
    final urls = <String, String>{};
    final list = data['urls'];
    if (list is List) {
      for (final entry in list) {
        if (entry is Map && entry['key'] is String && entry['url'] is String) {
          urls[entry['key'] as String] = entry['url'] as String;
        }
      }
    }
    final expiresIn = data['expires_in'];
    return (urls, expiresIn is int ? expiresIn : 0);
  };
}

final mediaUrlServiceProvider = Provider<MediaUrlService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MediaUrlService(signer: supabaseMediaSigner(client));
});
