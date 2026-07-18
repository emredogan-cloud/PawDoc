import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import 'image_compressor.dart' show kMaxUploadBytes;

class UploadResult {
  const UploadResult({required this.storageKey});
  final String storageKey;
}

/// E8c: calm, user-facing upload failure. [message] is safe to show in a
/// snackbar — it never leaks internals or a raw stack.
class UploadException implements Exception {
  const UploadException(this.message);
  final String message;
  @override
  String toString() => 'UploadException($message)';
}

/// Internal marker: a transient failure worth a bounded retry.
class _RetryableUpload implements Exception {
  const _RetryableUpload();
}

/// E8c upload-resilience bounds. Each network call is time-boxed so an upload
/// can never spin forever, and retries are capped so a hard failure surfaces
/// promptly instead of hanging the capture flow.
const Duration kUploadUrlTimeout = Duration(seconds: 15);
const Duration kUploadPutTimeout = Duration(seconds: 30);
const int kUploadMaxAttempts = 3;

/// E8c: pre-flight guard, pure + unit-testable (runs before any network I/O).
/// Defends the upload path even if a caller hands over un-compressed bytes.
void validateUploadBytes(Uint8List bytes, {int maxBytes = kMaxUploadBytes}) {
  if (bytes.isEmpty) {
    throw const UploadException(
        'There’s nothing to upload — try retaking the photo.');
  }
  if (bytes.length > maxBytes) {
    throw const UploadException(
        'This photo is too large to upload. Please try again with a smaller image.');
  }
}

/// Uploads bytes to Cloudflare R2 using a SHORT-LIVED PRESIGNED PUT URL minted
/// by the `generate-upload-url` Edge Function (CR #6). R2 write credentials are
/// NEVER embedded in the client — the function holds them server-side.
///
/// E8c hardening: a size/empty guard, per-call timeouts (no infinite wait), and
/// a bounded retry on transient failures (timeout / network / 5xx) with clear
/// messaging. Non-transient 4xx fail fast.
class UploadService {
  UploadService(this._client, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;

  Future<UploadResult> uploadJpeg(Uint8List jpegBytes) async {
    validateUploadBytes(jpegBytes); // size/empty guard before any network call

    for (var attempt = 1; attempt <= kUploadMaxAttempts; attempt++) {
      try {
        return await _attempt(jpegBytes);
      } on _RetryableUpload {
        if (attempt < kUploadMaxAttempts) {
          // Bounded linear backoff — never an unbounded wait.
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }
    throw const UploadException(
        'Upload failed — please check your connection and try again.');
  }

  Future<UploadResult> _attempt(Uint8List jpegBytes) async {
    // 1. Presigned URL (no client R2 creds; CR #6), time-boxed.
    final Map<dynamic, dynamic> data;
    try {
      final res = await _client.functions.invoke(
        'generate-upload-url',
        body: {'content_type': 'image/jpeg', 'ext': 'jpg'},
      ).timeout(kUploadUrlTimeout);
      if (res.data is! Map) {
        throw const _RetryableUpload();
      }
      data = res.data as Map;
    } on TimeoutException {
      throw const _RetryableUpload();
    } on FunctionException {
      // Edge error (often transient) — retry within the bounded budget.
      throw const _RetryableUpload();
    }
    final url = data['url'];
    final key = data['key'];
    if (url is! String || key is! String) {
      throw const UploadException(
          'Could not start the upload. Please try again.');
    }

    // 2. PUT straight to R2, time-boxed.
    final http.Response put;
    try {
      put = await _http.put(
        Uri.parse(url),
        headers: const {'Content-Type': 'image/jpeg'},
        body: jpegBytes,
      ).timeout(kUploadPutTimeout);
    } on TimeoutException {
      throw const _RetryableUpload();
    } on http.ClientException {
      throw const _RetryableUpload();
    }
    if (put.statusCode >= 500) {
      throw const _RetryableUpload(); // server hiccup → retry
    }
    if (put.statusCode < 200 || put.statusCode >= 300) {
      // 4xx (e.g. expired URL) — don't hammer the server; surface cleanly.
      throw UploadException(
          'Upload was rejected (HTTP ${put.statusCode}). Please try again.');
    }
    return UploadResult(storageKey: key);
  }
}

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(ref.watch(supabaseClientProvider));
});
