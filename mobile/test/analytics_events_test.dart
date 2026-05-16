/// Tests for the typed analytics event hierarchy.
///
/// The headline assertion is the **privacy contract**: no event property
/// may carry PII (email, raw symptom text, image bytes, storage keys,
/// pet names). The contract is enforced by enumerating every concrete
/// event via [kAllAnalyticsEventSamples] and checking the property keys
/// against a tabu list.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/shared/services/analytics_events.dart';

void main() {
  group('event name format', () {
    test('every event name is snake_case and non-empty', () {
      final namePattern = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final event in kAllAnalyticsEventSamples) {
        expect(event.name, isNotEmpty);
        expect(
          namePattern.hasMatch(event.name),
          isTrue,
          reason: '${event.runtimeType}.name "${event.name}" is not snake_case',
        );
      }
    });

    test('event names are unique', () {
      final names = kAllAnalyticsEventSamples.map((e) => e.name).toList();
      expect(names.toSet().length, names.length);
    });
  });

  group('privacy contract', () {
    // Any property key that contains one of these substrings is suspect.
    // The list is intentionally aggressive — better to false-positive on
    // a benign name than to leak PII.
    const taboo = [
      'email',
      'phone',
      'address',
      'text_description',
      'symptom',
      'image',
      'photo_data',
      'storage_key',
      'pet_name',
      'first_name',
      'last_name',
      'user_name',
      'password',
      'token',
    ];

    test('no event property key matches a PII tabu word', () {
      for (final event in kAllAnalyticsEventSamples) {
        for (final key in event.properties.keys) {
          final lower = key.toLowerCase();
          for (final word in taboo) {
            expect(
              lower.contains(word),
              isFalse,
              reason:
                  '${event.runtimeType}: property key "$key" '
                  'contains forbidden substring "$word"',
            );
          }
        }
      }
    });

    test('property values are primitives or category strings', () {
      for (final event in kAllAnalyticsEventSamples) {
        for (final entry in event.properties.entries) {
          final v = entry.value;
          if (v == null) continue;
          final isAllowed =
              v is num || v is bool || v is String || v is List || v is Map;
          expect(
            isAllowed,
            isTrue,
            reason:
                '${event.runtimeType}: property "${entry.key}" has '
                'disallowed runtime type ${v.runtimeType}',
          );
          if (v is String) {
            // Categories are short. Anything > 64 chars is suspicious
            // (might be a free-text description leaking).
            expect(
              v.length,
              lessThanOrEqualTo(64),
              reason:
                  '${event.runtimeType}: property "${entry.key}" value '
                  'is suspiciously long for a category',
            );
          }
        }
      }
    });
  });

  group('event-specific shape', () {
    test('AuthCompletedEvent.method is the AuthMethod enum value', () {
      const e = AuthCompletedEvent(method: AuthMethod.apple);
      expect(e.properties['method'], 'apple');
    });

    test('AnalysisCompletedEvent strips nothing useful', () {
      const e = AnalysisCompletedEvent(
        triageLevel: 'EMERGENCY',
        tierUsed: 2,
        latencyMs: 1234,
      );
      expect(e.properties, {
        'triage_level': 'EMERGENCY',
        'tier_used': 2,
        'latency_ms': 1234,
      });
    });

    test('UploadCompletedEvent carries only duration_ms', () {
      const e = UploadCompletedEvent(durationMs: 800);
      expect(e.properties.keys, ['duration_ms']);
    });
  });
}
