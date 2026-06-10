// M0 fix F-2 — the home hero's "Last check" recency label.
import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/core/last_check.dart';

void main() {
  final now = DateTime.utc(2026, 6, 10, 12, 0, 0);

  String at(Duration ago) => lastCheckLabel(now.subtract(ago), now: now);

  test('fresh checks read "just now"', () {
    expect(at(Duration.zero), 'just now');
    expect(at(const Duration(seconds: 30)), 'just now');
    expect(at(const Duration(minutes: 1, seconds: 59)), 'just now');
  });

  test('clock skew (server slightly ahead) is still "just now"', () {
    expect(lastCheckLabel(now.add(const Duration(seconds: 45)), now: now), 'just now');
  });

  test('minutes / hours ladder', () {
    expect(at(const Duration(minutes: 5)), '5 min ago');
    expect(at(const Duration(minutes: 59)), '59 min ago');
    expect(at(const Duration(hours: 1)), '1 h ago');
    expect(at(const Duration(hours: 23)), '23 h ago');
  });

  test('days / weeks / months ladder', () {
    expect(at(const Duration(hours: 25)), 'yesterday');
    expect(at(const Duration(days: 3)), '3 days ago');
    expect(at(const Duration(days: 8)), '1 wk ago');
    expect(at(const Duration(days: 45)), '1 mo ago');
    expect(at(const Duration(days: 400)), '1 yr ago');
  });
}
