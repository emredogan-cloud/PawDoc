import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';

class UploadResult {
  const UploadResult({required this.storageKey});
  final String storageKey;
}

/// Uploads bytes to Cloudflare R2 using a SHORT-LIVED PRESIGNED PUT URL minted
/// by the `generate-upload-url` Edge Function (CR #6). R2 write credentials are
/// NEVER embedded in the client — the function holds them server-side.
class UploadService {
  UploadService(this._client);

  final SupabaseClient _client;

  // GAP-E8(d): bound every network leg so a stalled upload surfaces an error
  // instead of an infinite spinner (the F-1 hang class). On timeout these throw
  // TimeoutException, which the capture flow handles as a normal failure.
  static const _invokeTimeout = Duration(seconds: 20);
  static const _putTimeout = Duration(seconds: 60);

  Future<UploadResult> uploadJpeg(Uint8List jpegBytes) async {
    // 1. Ask the Edge Function for a presigned URL + the storage key it minted.
    final res = await _client.functions.invoke(
      'generate-upload-url',
      body: {'content_type': 'image/jpeg', 'ext': 'jpg'},
    ).timeout(_invokeTimeout);
    final data = res.data;
    if (data is! Map || data['url'] == null || data['key'] == null) {
      throw Exception('Could not obtain an upload URL');
    }
    final url = data['url'] as String;
    final key = data['key'] as String;

    // 2. PUT the bytes straight to R2 (no credentials on the client).
    final put = await http.put(
      Uri.parse(url),
      headers: const {'Content-Type': 'image/jpeg'},
      body: jpegBytes,
    ).timeout(_putTimeout);
    if (put.statusCode < 200 || put.statusCode >= 300) {
      throw Exception('Upload failed (HTTP ${put.statusCode})');
    }
    return UploadResult(storageKey: key);
  }

  /// Upload several JPEG keyframes (Phase 3.2 video), each via its own presigned
  /// PUT URL. Returns the storage keys in order. Same no-client-credentials
  /// guarantee as [uploadJpeg].
  Future<List<String>> uploadFrames(List<Uint8List> frames) async {
    final keys = <String>[];
    for (final frame in frames) {
      final result = await uploadJpeg(frame);
      keys.add(result.storageKey);
    }
    return keys;
  }
}

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(ref.watch(supabaseClientProvider));
});
