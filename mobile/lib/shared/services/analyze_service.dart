/// Analyze service — calls the Supabase Edge Function `/analyze`.
///
/// We use the raw `supabase.functions.invoke` path which forwards the
/// signed user JWT for us. The edge function expects the body fields
/// defined in Phase 1B; the response is an [AnalysisResult].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/analysis_result.dart';
import '../models/pet.dart';
import 'logger.dart';
import 'supabase_client.dart';

/// All error shapes the edge function can return. Mobile maps each to
/// user-friendly copy; the controller stores the [AnalyzeFailureKind] so
/// callers can branch on type (e.g. show the paywall on `quotaExceeded`).
enum AnalyzeFailureKind {
  network,
  unauthorized,
  notFound,
  quotaExceeded,
  rateLimited,
  validation,
  upstreamUnavailable,
  unknown;

  String get userMessage => switch (this) {
    AnalyzeFailureKind.network =>
      'No internet connection. Reconnect and try again.',
    AnalyzeFailureKind.unauthorized =>
      'Your session has expired. Please sign in again.',
    AnalyzeFailureKind.notFound =>
      "We can't find that pet. Go back home and try again.",
    AnalyzeFailureKind.quotaExceeded =>
      "You've used your free analyses for this month. Upgrade to continue.",
    AnalyzeFailureKind.rateLimited =>
      "You've reached today's daily limit. Try again tomorrow.",
    AnalyzeFailureKind.validation =>
      "We couldn't process that request. Please try again.",
    AnalyzeFailureKind.upstreamUnavailable =>
      'Our AI service is unavailable right now. Try again in a minute.',
    AnalyzeFailureKind.unknown => 'Something went wrong. Try again shortly.',
  };
}

class AnalyzeFailure implements Exception {
  const AnalyzeFailure(this.kind, [this.detail]);
  final AnalyzeFailureKind kind;
  final String? detail;
  @override
  String toString() => detail ?? kind.userMessage;
}

abstract class AnalyzeService {
  Future<AnalysisResult> submit({
    required Pet pet,
    required String inputType, // 'photo' | 'video' | 'text'
    String? inputStorageKey,
    String? textDescription,
  });
}

class AnalyzeServiceImpl implements AnalyzeService {
  AnalyzeServiceImpl(this._client);
  final SupabaseClient _client;
  static final _log = AppLogger.of('analyze.service');

  @override
  Future<AnalysisResult> submit({
    required Pet pet,
    required String inputType,
    String? inputStorageKey,
    String? textDescription,
  }) async {
    final body = <String, Object?>{
      'pet_id': pet.id,
      'input_type': inputType,
      'input_storage_key': ?inputStorageKey,
      if (textDescription != null && textDescription.isNotEmpty)
        'text_description': textDescription,
    };

    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'analyze',
        method: HttpMethod.post,
        body: body,
      );
    } on FunctionException catch (e) {
      _log.warning('analyze_function_exception', '${e.status} ${e.details}');
      throw AnalyzeFailure(_kindFromStatus(e.status));
    } on Object catch (e, s) {
      _log.severe('analyze_unexpected', e, s);
      throw const AnalyzeFailure(AnalyzeFailureKind.network);
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      _log.warning('analyze_unexpected_shape', data.runtimeType.toString());
      throw const AnalyzeFailure(AnalyzeFailureKind.unknown);
    }
    try {
      return AnalysisResult.fromJson(data);
    } on FormatException catch (e) {
      _log.warning('analyze_parse_failed', e.message);
      throw const AnalyzeFailure(AnalyzeFailureKind.unknown);
    }
  }

  AnalyzeFailureKind _kindFromStatus(int? status) {
    if (status == null) return AnalyzeFailureKind.network;
    if (status == 401) return AnalyzeFailureKind.unauthorized;
    if (status == 402) return AnalyzeFailureKind.quotaExceeded;
    if (status == 404) return AnalyzeFailureKind.notFound;
    if (status == 422) return AnalyzeFailureKind.validation;
    if (status == 429) return AnalyzeFailureKind.rateLimited;
    if (status == 502 || status == 503 || status == 504) {
      return AnalyzeFailureKind.upstreamUnavailable;
    }
    return AnalyzeFailureKind.unknown;
  }
}

final analyzeServiceProvider = Provider<AnalyzeService>(
  (ref) => AnalyzeServiceImpl(ref.watch(supabaseClientProvider)),
);
