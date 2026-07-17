// GAP-A5: the mapper that makes non-2xx function responses visible (the bug was
// a blind catch discarding FunctionException.details).
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/functions_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('parses a 402 quota payload incl. the GAP-A3 teaser triage chip', () {
    final fe = asFunctionError(FunctionException(
      status: 402,
      details: {
        'error': 'free_limit_reached',
        'message': "You've used your free analyses this month.",
        'quota_exceeded': true,
        'action': 'CALL_TODAY',
      },
    ));
    expect(fe, isNotNull);
    expect(fe!.isQuotaExceeded, isTrue);
    expect(fe.code, 'free_limit_reached');
    expect(fe.message, contains('free analyses'));
    expect(fe.action, 'CALL_TODAY');
  });

  test('a text 402 (no triage chip) still maps to the quota wall', () {
    final fe = asFunctionError(FunctionException(
      status: 402,
      details: {'error': 'free_limit_reached', 'message': 'upgrade'},
    ));
    expect(fe!.isQuotaExceeded, isTrue);
    expect(fe.action, isNull);
  });

  test('a 5xx is surfaced but is NOT the quota wall (falls through to error)', () {
    final fe = asFunctionError(FunctionException(status: 503, details: {'message': 'down'}));
    expect(fe!.isQuotaExceeded, isFalse);
  });

  test('non-FunctionException returns null (generic error handling)', () {
    expect(asFunctionError(Exception('boom')), isNull);
    expect(asFunctionError('a string'), isNull);
  });
}
