import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';

/// Phase 6.3 — thrown when the Edge Function reports the user lacks an
/// entitlement (HTTP 402). The caller surfaces a paywall / RC offering.
class PdfReportPaywallException implements Exception {
  const PdfReportPaywallException(this.message);
  final String message;
  @override
  String toString() => 'PdfReportPaywallException($message)';
}

/// Invokes /generate-pdf-report, writes the bytes to the OS's TEMP directory,
/// and hands the file off to the system share sheet. The PDF is **never
/// stored permanently** — the temp file is reclaimed by the OS when temp
/// space is pressured or on app uninstall.
class PdfReportService {
  PdfReportService(this._client);
  final SupabaseClient _client;

  Future<String> generateAndShare({
    required String petId,
    required String petName,
  }) async {
    final resp = await _client.functions.invoke(
      'generate-pdf-report',
      body: {'pet_id': petId},
    );
    final status = resp.status;
    if (status == 402) {
      throw const PdfReportPaywallException('PDF reports are premium-included');
    }
    if (status < 200 || status >= 300) {
      throw Exception('PDF generation failed (status $status)');
    }
    final data = resp.data;
    final Uint8List bytes;
    if (data is Uint8List) {
      bytes = data;
    } else if (data is List<int>) {
      bytes = Uint8List.fromList(data);
    } else {
      throw Exception('Unexpected PDF response type: ${data.runtimeType}');
    }
    final dir = await getTemporaryDirectory();
    final safe = petName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]+'), '-');
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final path = '${dir.path}/pawdoc-$safe-$stamp.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    // Hand off to the OS share sheet — the user picks the destination. We
    // never upload the PDF; the file lives in temp until OS cleanup.
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'PawDoc Health Report'),
    );
    return file.path;
  }
}

final pdfReportServiceProvider = Provider<PdfReportService>((ref) {
  return PdfReportService(ref.watch(supabaseClientProvider));
});
