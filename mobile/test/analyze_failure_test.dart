/// Tests for AnalyzeFailureKind → user message mapping.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/shared/services/analyze_service.dart';

void main() {
  test('every failure kind has a non-empty user-facing message', () {
    for (final kind in AnalyzeFailureKind.values) {
      expect(kind.userMessage, isNotEmpty);
      expect(kind.userMessage.length, lessThan(200));
    }
  });

  test('messages never expose technical details', () {
    for (final kind in AnalyzeFailureKind.values) {
      final m = kind.userMessage.toLowerCase();
      // Negative-list known leaks.
      for (final taboo in const [
        'http',
        'fastapi',
        'supabase',
        'edge function',
        'stack trace',
        'exception',
        'null',
      ]) {
        expect(
          m.contains(taboo),
          isFalse,
          reason: '$kind exposes "$taboo": ${kind.userMessage}',
        );
      }
    }
  });

  test('AnalyzeFailure toString prefers explicit detail', () {
    const a = AnalyzeFailure(AnalyzeFailureKind.network, 'custom detail');
    expect(a.toString(), 'custom detail');
  });

  test('AnalyzeFailure toString falls back to kind copy', () {
    const a = AnalyzeFailure(AnalyzeFailureKind.network);
    expect(a.toString(), AnalyzeFailureKind.network.userMessage);
  });
}
