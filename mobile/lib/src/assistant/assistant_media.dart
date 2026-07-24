import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../capture/upload_service.dart';
import '../memories/memory_media_service.dart' show compressMemoryBytes;

/// Chat attachments (Next Evolution Phase 4): pick → compress (same
/// EXIF/GPS-stripping isolate as every other upload) → presigned PUT into the
/// caller's own `chat/<uid>/…` namespace. The storage key then rides the chat
/// message; the Edge Function presigns a short GET for the model only after
/// re-validating ownership.
class AssistantMediaService {
  AssistantMediaService(this._uploads, {ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final UploadService _uploads;
  final ImagePicker _picker;

  Future<Uint8List?> pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  Future<String> compressAndUpload(Uint8List raw) async {
    final compressed = await compute(compressMemoryBytes, raw);
    final result = await _uploads.uploadJpeg(compressed.bytes, scope: 'chat');
    return result.storageKey;
  }
}

final assistantMediaServiceProvider = Provider<AssistantMediaService>((ref) {
  return AssistantMediaService(ref.watch(uploadServiceProvider));
});
